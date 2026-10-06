//
//  ScanLocation.swift
//  DiskDuster
//

import Foundation

/// How a single cleanup item is removed.
nonisolated enum CleanMode: String, Sendable, Codable {
    /// Remove the item itself.
    case removeItem
    /// Remove everything inside the directory but keep the directory, since apps may expect it to exist.
    case removeContents
}

/// How a location's matches are turned into cleanup items.
nonisolated enum LocationScope: Sendable, Hashable {
    /// Each direct child of the location becomes its own item. Child directories are cleaned with the given
    /// mode; child files are always removed.
    case children(CleanMode)
    /// The location itself becomes one item, cleaned by removing its contents.
    case contents
}

/// A place on disk that DiskDuster scans for reclaimable files.
///
/// A `pattern` is an absolute path that may start with `~/` (the home folder), may start with
/// `$DARWIN_USER_CACHE_DIR` (the per-user cache folder under /private/var/folders), and may contain `*` as a
/// whole path component to match every non-hidden entry at that level.
nonisolated struct ScanLocation: Identifiable, Sendable, Hashable {
    static let darwinCacheToken = "$DARWIN_USER_CACHE_DIR"

    let category: CleanupCategory
    let pattern: String
    let label: String
    let scope: LocationScope
    let selectedByDefault: Bool
    /// The location is protected by macOS privacy controls and can only be read with Full Disk Access.
    let needsFullDiskAccess: Bool
    /// Items are deleted permanently even when the user prefers moving to the Trash.
    let alwaysPermanent: Bool
    let note: String?

    var id: String { pattern }
    var requiresAdmin: Bool { category.requiresAdmin }

    init(
        _ category: CleanupCategory,
        _ pattern: String,
        label: String,
        scope: LocationScope,
        selected: Bool = true,
        needsFullDiskAccess: Bool = false,
        alwaysPermanent: Bool = false,
        note: String? = nil
    ) {
        self.category = category
        self.pattern = pattern
        self.label = label
        self.scope = scope
        self.selectedByDefault = selected
        self.needsFullDiskAccess = needsFullDiskAccess
        self.alwaysPermanent = alwaysPermanent
        self.note = note
    }
}
