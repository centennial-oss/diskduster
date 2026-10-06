//
//  PathSafety.swift
//  DiskDuster
//

import Foundation

nonisolated struct UnsafePathError: Error, LocalizedError, Equatable {
    let reason: String
    var errorDescription: String? { reason }
}

/// The last line of defense before anything is removed. Every item is re-checked against the catalog so a
/// stale, edited or tampered-with item can never point DiskDuster at something it did not scan for.
nonisolated enum PathSafety {
    static func validate(_ item: CleanupItem, in env: ScanEnvironment) throws(UnsafePathError) {
        guard let location = LocationCatalog.location(withID: item.locationID) else {
            throw UnsafePathError(reason: "Not from a known scan location.")
        }
        guard item.category == location.category, item.requiresAdmin == location.requiresAdmin else {
            throw UnsafePathError(reason: "Does not match its scan location.")
        }
        guard isCanonicalAbsolute(item.path), isCanonicalAbsolute(item.rootPath) else {
            throw UnsafePathError(reason: "Path is not absolute and canonical.")
        }
        guard PathResolver.matches(item.rootPath, pattern: location.pattern, in: env) else {
            throw UnsafePathError(reason: "Is outside its scan location.")
        }
        guard ScanEnvironment.realPath(item.rootPath) == item.rootPath else {
            throw UnsafePathError(reason: "Its location is reached through a symbolic link.")
        }
        guard !LocationCatalog.protectedNames.contains(item.ownerName) else {
            throw UnsafePathError(reason: "Is protected.")
        }
        try validateShape(item, scope: location.scope)
    }

    private static func validateShape(_ item: CleanupItem, scope: LocationScope) throws(UnsafePathError) {
        switch scope {
        case .contents:
            guard item.path == item.rootPath, item.cleanMode == .removeContents else {
                throw UnsafePathError(reason: "Only the contents of this location may be removed.")
            }
        case .children:
            let parent = (item.path as NSString).deletingLastPathComponent
            let name = (item.path as NSString).lastPathComponent
            guard parent == item.rootPath, PathResolver.isSafeComponent(name) else {
                throw UnsafePathError(reason: "Is not directly inside its scan location.")
            }
        }
        if item.cleanMode == .removeContents && !PathResolver.isRealDirectory(item.path) {
            throw UnsafePathError(reason: "Is no longer a folder.")
        }
    }

    /// An absolute path with no empty, `.` or `..` components and no trailing slash.
    static func isCanonicalAbsolute(_ path: String) -> Bool {
        guard path.hasPrefix("/"), path.count > 1, !path.hasSuffix("/") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).dropFirst().allSatisfy {
            PathResolver.isSafeComponent($0)
        }
    }

    /// Quotes a value for POSIX `sh` so it is always treated as a single literal word.
    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
