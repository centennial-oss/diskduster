//
//  AppDirectory.swift
//  DiskDuster
//

import Foundation

nonisolated struct InstalledApp: Sendable, Hashable {
    let bundleID: String
    let name: String
    let path: String
}

/// An index of installed apps, used to work out which app owns a cache or log folder so the user can preserve
/// everything that belongs to one app in a single step.
nonisolated struct AppDirectory: Sendable {
    private(set) var byBundleID: [String: InstalledApp] = [:]
    private(set) var byName: [String: InstalledApp] = [:]

    static func scan(homePath: String) -> AppDirectory {
        var directory = AppDirectory()
        let folders = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Cryptexes/App/System/Applications",
            homePath + "/Applications"
        ]
        for folder in folders {
            for name in (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
            where name.hasSuffix(".app") {
                if let app = readApp(at: folder + "/" + name) { directory.add(app) }
            }
        }
        return directory
    }

    mutating func add(_ app: InstalledApp) {
        byBundleID[app.bundleID.lowercased()] = byBundleID[app.bundleID.lowercased()] ?? app
        byName[Self.normalizedName(app.name)] = byName[Self.normalizedName(app.name)] ?? app
    }

    private static func readApp(at path: String) -> InstalledApp? {
        let plistURL = URL(filePath: path + "/Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = info["CFBundleIdentifier"] as? String else { return nil }
        let fileName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? fileName
        return InstalledApp(bundleID: bundleID, name: name.isEmpty ? fileName : name, path: path)
    }

    /// Finds the app that a folder name most likely belongs to, or nil if no installed app matches.
    ///
    /// Handles plain bundle IDs (`com.apple.Music`), helper suffixes (`com.microsoft.VSCode.ShipIt`), app group
    /// prefixes (`group.com.apple.notes`), team ID prefixes (`UBF8T346G9.com.microsoft.teams`) and folders
    /// named after the app (`Slack`).
    func owner(of folderName: String) -> InstalledApp? {
        if let app = byName[Self.normalizedName(folderName)] { return app }
        var parts = folderName.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return nil }
        if parts.first?.lowercased() == "group" { parts.removeFirst() }
        if let first = parts.first, Self.looksLikeTeamID(first) { parts.removeFirst() }
        while parts.count >= 2 {
            if let app = byBundleID[parts.joined(separator: ".").lowercased()] { return app }
            parts.removeLast()
        }
        return nil
    }

    static func normalizedName(_ name: String) -> String {
        name.lowercased().filter { !$0.isWhitespace }
    }

    /// Apple team IDs are ten uppercase letters and digits.
    static func looksLikeTeamID(_ text: String) -> Bool {
        text.count == 10 && text.allSatisfy { $0.isUppercase || $0.isNumber }
    }
}
