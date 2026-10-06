//
//  VolumeInfo.swift
//  DiskDuster
//

import Foundation

/// Capacity of the volume that holds the home folder.
nonisolated struct VolumeInfo: Sendable, Equatable {
    let name: String
    let totalBytes: Int64
    /// Free space as Finder reports it.
    let availableBytes: Int64
    /// Purgeable space macOS holds for itself (local snapshots, iCloud copies, system caches) and frees on demand.
    var reservedBytes: Int64 = 0

    var usedFraction: Double {
        totalBytes > 0 ? Double(totalBytes - availableBytes) / Double(totalBytes) : 0
    }

    static func forHomeVolume() -> VolumeInfo? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // Plain available capacity is what Finder shows. The "important usage" figure also counts purgeable
        // space, such as files still held by local Time Machine snapshots, so it can be far higher than Finder.
        let keys: Set<URLResourceKey> = [
            .volumeLocalizedNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? home.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacity else { return nil }
        // Free space including purgeable, minus plain free space, is what macOS is holding for itself.
        let withPurgeable = values.volumeAvailableCapacityForImportantUsage ?? Int64(available)
        return VolumeInfo(
            name: values.volumeLocalizedName ?? "Macintosh HD",
            totalBytes: Int64(total),
            availableBytes: Int64(available),
            reservedBytes: max(0, withPurgeable - Int64(available))
        )
    }
}

/// How the startup disk splits up, for the colored capacity bar. Selected bytes are clamped so the parts
/// always add up to the disk's size.
nonisolated struct CapacityBreakdown: Equatable, Sendable {
    let total: Int64
    let free: Int64
    let reserved: Int64
    let fullySelected: Int64
    let partlySelected: Int64

    /// Free space plus what macOS frees on demand: what Finder and Get Info call "available".
    var available: Int64 { free + reserved }

    /// Space in use that DiskDuster isn't set to clean.
    var inUse: Int64 { max(0, total - free - reserved - fullySelected - partlySelected) }

    init(volume: VolumeInfo, fullySelected: Int64, partlySelected: Int64) {
        total = max(0, volume.totalBytes)
        free = min(max(0, volume.availableBytes), total)
        reserved = min(max(0, volume.reservedBytes), total - free)
        let used = total - free - reserved
        self.fullySelected = min(max(0, fullySelected), used)
        self.partlySelected = min(max(0, partlySelected), used - self.fullySelected)
    }

    func fraction(_ bytes: Int64) -> Double {
        total > 0 ? Double(bytes) / Double(total) : 0
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
