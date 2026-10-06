//
//  DirectorySizer.swift
//  DiskDuster
//

import Darwin
import Foundation

nonisolated struct SizeResult: Sendable, Equatable {
    var bytes: Int64 = 0
    /// Something inside could not be read, so `bytes` is a lower bound.
    var isPartial = false
}

/// Measures disk usage the way `du` does: allocated blocks, never following symlinks or crossing volumes,
/// and counting hard-linked files once.
nonisolated enum DirectorySizer {
    static func allocatedSize(atPath path: String) -> SizeResult {
        var result = SizeResult()
        guard let cPath = strdup(path) else { return result }
        defer { free(cPath) }
        let argv: [UnsafeMutablePointer<CChar>?] = [cPath, nil]
        guard let stream = fts_open(argv, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else {
            result.isPartial = true
            return result
        }
        defer { fts_close(stream) }

        var seenLinks = Set<FileIdentity>()
        var visited = 0
        while let entry = fts_read(stream) {
            visited += 1
            if visited.isMultiple(of: 4096), Task.isCancelled { break }
            switch Int32(entry.pointee.fts_info) {
            case FTS_DP, FTS_DC:
                continue
            case FTS_DNR, FTS_ERR, FTS_NS:
                result.isPartial = true
                if Int32(entry.pointee.fts_info) == FTS_NS { continue }
            default:
                break
            }
            guard let info = entry.pointee.fts_statp?.pointee else { continue }
            let isDirectory = (info.st_mode & S_IFMT) == S_IFDIR
            if !isDirectory && info.st_nlink > 1 {
                let identity = FileIdentity(device: info.st_dev, inode: info.st_ino)
                if !seenLinks.insert(identity).inserted { continue }
            }
            result.bytes += Int64(info.st_blocks) * 512
        }
        return result
    }
}
