//
//  PathResolver.swift
//  DiskDuster
//

import Darwin
import Foundation

/// A match of a location pattern against the real filesystem.
nonisolated struct ResolvedRoot: Sendable, Hashable {
    let path: String
    /// The path component matched by `*`, or the last component when the pattern has no wildcard.
    let ownerName: String
}

/// Expands location patterns into real directories and checks paths against patterns.
nonisolated enum PathResolver {
    /// Finds every real directory that matches the pattern and is not reached through a symlink at any level.
    static func expand(_ pattern: String, in env: ScanEnvironment) -> [ResolvedRoot] {
        guard let absolute = env.substitute(pattern), absolute.hasPrefix("/") else { return [] }
        let components = absolute.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        var partials: [(path: String, owner: String?)] = [("", nil)]
        for component in components {
            var next: [(path: String, owner: String?)] = []
            for partial in partials {
                if component == "*" {
                    let parent = partial.path.isEmpty ? "/" : partial.path
                    for name in listVisibleNames(parent) {
                        next.append((partial.path + "/" + name, name))
                    }
                } else {
                    next.append((partial.path + "/" + component, partial.owner))
                }
            }
            partials = next
        }
        return partials.compactMap { partial in
            guard isRealDirectory(partial.path), ScanEnvironment.realPath(partial.path) == partial.path else {
                return nil
            }
            let owner = partial.owner ?? (partial.path as NSString).lastPathComponent
            return ResolvedRoot(path: partial.path, ownerName: owner)
        }
    }

    /// Returns true when `path` is exactly what `pattern` would produce, treating `*` as one path component.
    static func matches(_ path: String, pattern: String, in env: ScanEnvironment) -> Bool {
        guard let absolute = env.substitute(pattern) else { return false }
        let pathParts = path.split(separator: "/", omittingEmptySubsequences: false)
        let patternParts = absolute.split(separator: "/", omittingEmptySubsequences: false)
        guard pathParts.count == patternParts.count else { return false }
        for (part, expected) in zip(pathParts, patternParts) {
            if expected == "*" {
                if !isSafeComponent(part) { return false }
            } else if part != expected {
                return false
            }
        }
        return true
    }

    static func isSafeComponent<S: StringProtocol>(_ name: S) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/")
    }

    static func listVisibleNames(_ directory: String) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        return names.filter { !$0.hasPrefix(".") }.sorted()
    }

    /// True when the path exists and is a directory, without following a final symlink.
    static func isRealDirectory(_ path: String) -> Bool {
        var info = stat()
        guard lstat(path, &info) == 0 else { return false }
        return (info.st_mode & S_IFMT) == S_IFDIR
    }

    static func fileIdentity(_ path: String) -> FileIdentity? {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        return FileIdentity(device: info.st_dev, inode: info.st_ino)
    }
}

/// Identifies a file regardless of the path used to reach it, so case variants are not counted twice.
nonisolated struct FileIdentity: Hashable, Sendable {
    let device: Int32
    let inode: UInt64
}
