//
//  AIProfile.swift
//  DiskDuster
//

import CryptoKit
import Foundation

/// The configuration profile DiskDuster asks the user to install. It switches features off with Apple's
/// restriction keys, pins settings that have no restriction key, and stops macOS from downloading removed
/// models again. Removing the profile in System Settings undoes all of it.
nonisolated enum AIProfile {
    static let identifier = "org.centennialoss.diskduster.apple-intelligence"
    static let displayName = "DiskDuster: Apple Intelligence Off"

    /// A preference domain only this profile writes, so DiskDuster can tell whether the profile is installed
    /// and which features it covers.
    static let markerDomain = "org.centennialoss.diskduster.ai-controls"
    static let markerVersionKey = "ProfileVersion"
    static let markerFeaturesKey = "DisabledFeatures"
    static let profileVersion = 1

    /// macOS fetches each model type from a server it can be told to override. Pointing it at a closed port on
    /// this Mac makes downloads fail instead of quietly refilling the disk.
    static let assetDomain = "com.apple.MobileAsset"
    static let unreachableServer = "https://127.0.0.1:1/blocked-by-diskduster/"

    static func downloadOverrideKey(for pack: AIModelPack) -> String {
        "DownloadServerBaseURLOverride-" + pack.expectedAssetType
    }

    static func makeData(disabling features: Set<AIFeature>) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: makeProfile(disabling: features), format: .xml, options: 0)
    }

    static func makeProfile(disabling features: Set<AIFeature>) -> [String: Any] {
        let ordered = AIFeature.allCases.filter(features.contains)
        var payloads: [[String: Any]] = []

        let restrictionKeys = ordered.flatMap(\.restrictionKeys)
        if !restrictionKeys.isEmpty {
            var restrictions = payloadHeader(type: "com.apple.applicationaccess", name: "Apple Intelligence features")
            for key in restrictionKeys { restrictions[key] = false }
            payloads.append(restrictions)
        }

        // One managed-preferences payload per domain. macOS 27 dropped every domain when they shared a single
        // payload, so each gets its own, with DiskDuster's marker first.
        var pinned = pinnedValues(for: ordered)
        pinned[markerDomain] = [
            markerVersionKey: profileVersion,
            markerFeaturesKey: ordered.map(\.rawValue)
        ]
        let domains = [markerDomain] + pinned.keys.filter { $0 != markerDomain }.sorted()
        for domain in domains {
            guard let values = pinned[domain] else { continue }
            var managed = payloadHeader(
                type: "com.apple.ManagedClient.preferences", name: "Pinned settings: \(domain)",
                // ".GlobalPreferences" would otherwise put two dots in a row in the payload identifier.
                suffix: domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            )
            managed["PayloadContent"] = [domain: ["Forced": [["mcx_preference_settings": values]]]]
            payloads.append(managed)
        }

        return [
            "PayloadType": "Configuration",
            "PayloadVersion": 1,
            "PayloadIdentifier": identifier,
            "PayloadUUID": stableUUID(for: identifier),
            "PayloadDisplayName": displayName,
            "PayloadOrganization": "Centennial OSS",
            "PayloadDescription": "Installed by DiskDuster. Turns off the Apple Intelligence features you chose and "
                + "keeps their models from downloading again. Remove this profile to turn them back on.",
            "PayloadScope": "System",
            "PayloadRemovalDisallowed": false,
            "PayloadContent": payloads
        ]
    }

    /// Settings to pin, grouped by preference domain, including the download overrides for removed models.
    private static func pinnedValues(for features: [AIFeature]) -> [String: [String: Any]] {
        var values: [String: [String: Any]] = [:]
        for setting in features.flatMap(\.pinnedSettings) {
            values[setting.domain, default: [:]][setting.key] = setting.disabledValue
        }
        for pack in AIFeature.removablePacks(turningOff: Set(features)) {
            values[assetDomain, default: [:]][downloadOverrideKey(for: pack)] = unreachableServer
        }
        return values
    }

    private static func payloadHeader(type: String, name: String, suffix: String? = nil) -> [String: Any] {
        let payloadID = [identifier, type, suffix].compactMap { $0 }.joined(separator: ".")
        return [
            "PayloadType": type,
            "PayloadVersion": 1,
            "PayloadIdentifier": payloadID,
            "PayloadUUID": stableUUID(for: payloadID),
            "PayloadDisplayName": name
        ]
    }

    /// The same name always yields the same UUID, so installing an updated profile replaces the old one.
    static func stableUUID(for name: String) -> String {
        var bytes = Array(SHA256.hash(data: Data(("diskduster:" + name).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80   // version 8: custom
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC 4122 variant
        let uuid = bytes.withUnsafeBytes { $0.loadUnaligned(as: uuid_t.self) }
        return UUID(uuid: uuid).uuidString
    }

    // MARK: - Installed state

    /// The features the installed profile turns off, or nil when DiskDuster's profile isn't installed.
    static func installedFeatures() -> Set<AIFeature>? {
        let domain = markerDomain as CFString
        CFPreferencesAppSynchronize(domain)
        guard CFPreferencesAppValueIsForced(markerVersionKey as CFString, domain) else { return nil }
        let names = CFPreferencesCopyAppValue(markerFeaturesKey as CFString, domain) as? [String] ?? []
        return Set(names.compactMap(AIFeature.init(rawValue:)))
    }

    /// Where the profile is saved before macOS imports it.
    static func fileURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let folder = support.appending(path: "DiskDuster", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "DiskDuster Apple Intelligence.mobileconfig")
    }
}
