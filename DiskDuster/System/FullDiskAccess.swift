//
//  FullDiskAccess.swift
//  DiskDuster
//

import Darwin
import Foundation

/// Detects whether macOS has granted DiskDuster Full Disk Access. There is no API for this, so we probe
/// files that macOS privacy protection only lets FDA-approved apps read.
nonisolated enum FullDiskAccess {
    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
    )

    static func isGranted() -> Bool {
        if canOpen("/Library/Application Support/com.apple.TCC/TCC.db") { return true }
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        return canList(home + "/Library/Safari") || canList(home + "/.Trash")
    }

    private static func canOpen(_ path: String) -> Bool {
        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else { return false }
        close(descriptor)
        return true
    }

    private static func canList(_ path: String) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
    }
}
