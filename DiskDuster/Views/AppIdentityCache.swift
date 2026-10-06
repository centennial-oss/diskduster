//
//  AppIdentityCache.swift
//  DiskDuster
//

import AppKit

/// Turns bundle identifiers found in cache folder names into friendly app names and icons.
final class AppIdentityCache {
    static let shared = AppIdentityCache()

    private var appURLs: [String: URL?] = [:]
    private var icons: [String: NSImage] = [:]

    func displayName(for item: CleanupItem) -> String {
        if let owner = item.owningApp { return owner.name }
        guard let url = appURL(for: item) else { return item.ownerName }
        return FileManager.default.displayName(atPath: url.path(percentEncoded: false))
            .replacingOccurrences(of: ".app", with: "")
    }

    func icon(for item: CleanupItem) -> NSImage {
        let iconPath = item.owningApp?.path ?? appURL(for: item)?.path(percentEncoded: false) ?? item.path
        if let cached = icons[iconPath] { return cached }
        let image = NSWorkspace.shared.icon(forFile: iconPath)
        icons[iconPath] = image
        return image
    }

    private func appURL(for item: CleanupItem) -> URL? {
        guard let bundleID = item.likelyBundleIdentifier else { return nil }
        if let cached = appURLs[bundleID] { return cached }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        appURLs[bundleID] = url
        return url
    }
}
