//
//  AISnapshot.swift
//  DiskDuster
//

import Darwin
import Foundation

nonisolated enum AIFeatureState: Sendable, Equatable {
    /// Turned off by DiskDuster's profile.
    case offByDiskDuster
    /// Turned off by another configuration profile, such as one from an employer or school.
    case offByOtherProfile
    case off
    case enabled
    /// Has no per-user switch DiskDuster can read; it works whenever Apple Intelligence is on.
    case available
    case unknown

    var label: String {
        switch self {
        case .offByDiskDuster: "Off · DiskDuster"
        case .offByOtherProfile: "Off · Managed"
        case .off: "Off"
        case .enabled: "On"
        case .available: "Available"
        case .unknown: "Unknown"
        }
    }

    var isOff: Bool {
        self == .offByDiskDuster || self == .offByOtherProfile || self == .off
    }
}

/// A read-only picture of Apple Intelligence on this Mac: what's on, what's installed, and how big it is.
nonisolated struct AISnapshot: Sendable {
    var isSupported = false
    /// The features DiskDuster's profile turns off, or nil when the profile isn't installed.
    var profileFeatures: Set<AIFeature>?
    var states: [AIFeature: AIFeatureState] = [:]
    /// Bytes on disk per pack. A missing entry means the size couldn't be read.
    var packBytes: [AIModelPack: Int64] = [:]

    var totalModelBytes: Int64? {
        let known = AIModelPack.allCases.compactMap { packBytes[$0] }
        return known.count == AIModelPack.allCases.count ? known.reduce(0, +) : nil
    }

    func bytes(of packs: [AIModelPack]) -> Int64 {
        packs.compactMap { packBytes[$0] }.reduce(0, +)
    }

    @concurrent
    static func capture() async -> AISnapshot {
        captureNow()
    }

    static func captureNow() -> AISnapshot {
        var snapshot = AISnapshot()
        snapshot.isSupported = isPlatformSupported && AssetService.isAvailable
        snapshot.profileFeatures = AIProfile.installedFeatures()
        if snapshot.isSupported {
            snapshot.packBytes = readPackSizes()
        }
        for feature in AIFeature.allCases {
            snapshot.states[feature] = state(of: feature, in: snapshot)
        }
        return snapshot
    }

    /// macOS 26 and earlier have a single Apple Intelligence switch in System Settings, so DiskDuster only
    /// offers these controls on macOS 27 and later.
    static let minimumMajorVersion = 27

    static func supportsOS(majorVersion: Int) -> Bool {
        majorVersion >= minimumMajorVersion
    }

    /// Apple Intelligence needs Apple silicon, and DiskDuster's controls need macOS 27 or later.
    static var isPlatformSupported: Bool {
        isAppleSilicon && supportsOS(majorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }

    static func readPackSizes() -> [AIModelPack: Int64] {
        guard let inventory = AssetService.installedBytesByAssetType() else { return [:] }
        var sizes: [AIModelPack: Int64] = [:]
        for pack in AIModelPack.allCases {
            // The inventory only lists assets that are present, so a missing type means nothing is installed.
            sizes[pack] = inventory[pack.expectedAssetType] ?? 0
        }
        return sizes
    }

    static func state(of feature: AIFeature, in snapshot: AISnapshot) -> AIFeatureState {
        if snapshot.profileFeatures?.contains(feature) == true { return .offByDiskDuster }
        if feature.isModelOnly {
            let sizes = feature.modelPacks.map { snapshot.packBytes[$0] }
            if sizes.contains(where: { ($0 ?? 0) > 0 }) { return .enabled }
            return sizes.allSatisfy { $0 == 0 } ? .off : .unknown
        }
        if isForcedOff(feature) { return .offByOtherProfile }
        guard !feature.pinnedSettings.isEmpty else { return .available }
        let allOff = feature.pinnedSettings.allSatisfy { currentValue($0) == $0.disabledValue }
        return allOff ? .off : .enabled
    }

    private static func isForcedOff(_ feature: AIFeature) -> Bool {
        let restrictions = "com.apple.applicationaccess"
        let restrictionsForced = feature.restrictionKeys.allSatisfy { key in
            isForced(domain: restrictions, key: key) && readBool(restrictions, key) == false
        }
        let settingsForced = feature.pinnedSettings.allSatisfy { setting in
            isForced(domain: setting.domain, key: setting.key) && currentValue(setting) == setting.disabledValue
        }
        return restrictionsForced && settingsForced
    }

    private static func isForced(domain: String, key: String) -> Bool {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesAppValueIsForced(key as CFString, domain as CFString)
    }

    private static func currentValue(_ setting: PinnedSetting) -> Bool? {
        readBool(setting.domain, setting.key)
    }

    private static func readBool(_ domain: String, _ key: String) -> Bool? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Bool
    }
}
