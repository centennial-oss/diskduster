//
//  ScanEnvironment.swift
//  DiskDuster
//

import Darwin
import Foundation

/// The user-specific facts needed to turn location patterns into real paths.
nonisolated struct ScanEnvironment: Sendable {
    /// The real (symlink-free) path of the home folder, without a trailing slash.
    let homePath: String
    /// The real path of the per-user cache folder under /private/var/folders, if macOS reports one.
    let darwinCachePath: String?
    let hasFullDiskAccess: Bool
    let ignoredPaths: Set<String>

    static func current(hasFullDiskAccess: Bool, ignoredPaths: Set<String>) -> ScanEnvironment {
        // Unsandboxed, so this is the real home folder rather than a container.
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        return ScanEnvironment(
            homePath: realPath(home) ?? trimmingSlash(home),
            darwinCachePath: darwinUserCacheDirectory(),
            hasFullDiskAccess: hasFullDiskAccess,
            ignoredPaths: ignoredPaths
        )
    }

    /// Resolves symlinks and returns the canonical absolute path, or nil if it does not exist.
    static func realPath(_ path: String) -> String? {
        guard let resolved = Darwin.realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    static func trimmingSlash(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// The per-user cache folder (`/private/var/folders/xx/yyyy/C`) for the current user.
    static func darwinUserCacheDirectory() -> String? {
        let length = confstr(_CS_DARWIN_USER_CACHE_DIR, nil, 0)
        guard length > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: length)
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, length) > 0 else { return nil }
        let path = buffer.withUnsafeBufferPointer { ptr in
            ptr.baseAddress.map { String(cString: $0) } ?? ""
        }
        guard !path.isEmpty else { return nil }
        return realPath(path) ?? trimmingSlash(path)
    }

    /// Replaces `~/` and the per-user cache token in a pattern. Returns nil if the pattern cannot apply.
    func substitute(_ pattern: String) -> String? {
        if pattern.hasPrefix("~/") {
            return homePath + pattern.dropFirst(1)
        }
        if pattern.hasPrefix(ScanLocation.darwinCacheToken) {
            guard let darwinCachePath else { return nil }
            return darwinCachePath + pattern.dropFirst(ScanLocation.darwinCacheToken.count)
        }
        return pattern
    }
}
