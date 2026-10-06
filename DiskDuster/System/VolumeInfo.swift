//
//  VolumeInfo.swift
//  DiskDuster
//

import Foundation

/// Capacity of the volume that holds the home folder.
nonisolated struct VolumeInfo: Sendable, Equatable {
    let name: String
    let totalBytes: Int64
    let availableBytes: Int64

    var usedFraction: Double {
        totalBytes > 0 ? Double(totalBytes - availableBytes) / Double(totalBytes) : 0
    }

    static func forHomeVolume() -> VolumeInfo? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [
            .volumeLocalizedNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? home.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return VolumeInfo(
            name: values.volumeLocalizedName ?? "Macintosh HD",
            totalBytes: Int64(total),
            availableBytes: available
        )
    }
}

nonisolated enum ByteFormat {
    static func string(_ bytes: Int64, partial: Bool = false) -> String {
        let text = bytes.formatted(.byteCount(style: .file))
        return partial ? text + "+" : text
    }

    static func selected(_ bytes: Int64) -> String {
        bytes > 0 ? "\(string(bytes)) selected" : "None selected"
    }
}
