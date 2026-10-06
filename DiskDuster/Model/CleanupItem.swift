//
//  CleanupItem.swift
//  DiskDuster
//

import Foundation

/// One thing DiskDuster can clean: a file or folder to remove, or a folder to empty.
nonisolated struct CleanupItem: Identifiable, Hashable, Sendable {
    /// The absolute path of the item.
    let path: String
    /// The expanded location folder this item was found in.
    let rootPath: String
    let locationID: String
    let category: CleanupCategory
    let cleanMode: CleanMode
    /// The name of the folder or file that identifies who owns the item, often a bundle identifier.
    let ownerName: String
    let locationLabel: String
    var size: Int64
    /// Some of the item could not be read, so `size` is a lower bound.
    var sizeIsPartial: Bool
    let requiresAdmin: Bool
    let alwaysPermanent: Bool
    let selectedByDefault: Bool
    let note: String?
    /// The installed app this item belongs to, when one could be identified.
    var owningApp: InstalledApp?

    var id: String { path }

    /// Groups every item that belongs to the same app, across all categories. Items with no identifiable app
    /// are grouped by their folder name instead.
    var appKey: String {
        if let owningApp { return "app:" + owningApp.bundleID.lowercased() }
        return "folder:" + ownerName.lowercased()
    }
    var url: URL { URL(filePath: path) }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let trimmedHome = home.hasSuffix("/") ? String(home.dropLast()) : home
        if path.hasPrefix(trimmedHome + "/") {
            return "~" + path.dropFirst(trimmedHome.count)
        }
        return path
    }

    /// Owner names like `com.example.App` are probably bundle identifiers.
    var likelyBundleIdentifier: String? {
        let parts = ownerName.split(separator: ".")
        guard parts.count >= 2, !ownerName.contains(" "), !ownerName.contains("/") else { return nil }
        return ownerName
    }
}
