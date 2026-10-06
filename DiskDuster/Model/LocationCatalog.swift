//
//  LocationCatalog.swift
//  DiskDuster
//

import Foundation

/// Every location DiskDuster scans. Anything not listed here is never touched.
///
/// Deliberately excluded:
/// - Localization folders inside app bundles: removing them breaks the app's code signature.
/// - `/System/Library/Caches`: protected by System Integrity Protection.
/// - `~/Library/Developer/CoreSimulator/Devices`: that is where simulators themselves live.
nonisolated enum LocationCatalog {
    static let all: [ScanLocation] = userLocations + developerLocations + systemLocations

    static func location(withID id: String) -> ScanLocation? {
        all.first { $0.id == id }
    }

    /// Child names that are never offered for cleaning, because deleting them forces iCloud to resync or
    /// because they belong to DiskDuster itself.
    static let protectedNames: Set<String> = [
        "CloudKit",
        "com.apple.bird",
        "com.apple.cloudd",
        "org.centennialoss.diskduster"
    ]

    private static let userLocations: [ScanLocation] = [
        ScanLocation(.userCaches, "~/Library/Caches", label: "User Cache", scope: .children(.removeItem)),
        ScanLocation(
            .appCaches, "~/Library/Containers/*/Data/Library/Caches",
            label: "Container Cache", scope: .contents, needsFullDiskAccess: true
        ),
        ScanLocation(
            .appCaches, "~/Library/Group Containers/*/Library/Caches",
            label: "Group Container Cache", scope: .contents, needsFullDiskAccess: true
        ),
        ScanLocation(.appCaches, "~/Library/Application Support/*/Cache", label: "Cache", scope: .contents),
        ScanLocation(.appCaches, "~/Library/Application Support/*/Code Cache", label: "Code Cache", scope: .contents),
        ScanLocation(.appCaches, "~/Library/Application Support/*/GPUCache", label: "GPU Cache", scope: .contents),
        ScanLocation(
            .appCaches, "~/Library/Application Support/*/DawnGraphiteCache",
            label: "Graphics Cache", scope: .contents
        ),
        ScanLocation(
            .appCaches, "~/Library/Application Support/*/DawnWebGPUCache",
            label: "WebGPU Cache", scope: .contents
        ),
        ScanLocation(
            .appCaches, ScanLocation.darwinCacheToken,
            label: "macOS Per-User Cache", scope: .children(.removeItem), selected: false,
            note: "Used by macOS services and running apps. Quit apps before cleaning."
        ),
        ScanLocation(.logs, "~/Library/Logs", label: "User Logs", scope: .children(.removeItem)),
        ScanLocation(.logs, "~/Library/Application Support/*/logs", label: "App Logs", scope: .contents),
        ScanLocation(
            .trash, "~/.Trash", label: "Trash", scope: .children(.removeItem),
            needsFullDiskAccess: true, alwaysPermanent: true
        )
    ]

    private static let developerLocations: [ScanLocation] = [
        ScanLocation(
            .developer, "~/Library/Developer/Xcode/DerivedData",
            label: "Xcode DerivedData", scope: .children(.removeItem)
        ),
        ScanLocation(
            .developer, "~/Library/Developer/Xcode/iOS DeviceSupport",
            label: "iOS Device Support", scope: .children(.removeItem), selected: false,
            note: "Xcode copies these again the next time you connect a device."
        ),
        ScanLocation(
            .developer, "~/Library/Developer/Xcode/watchOS DeviceSupport",
            label: "watchOS Device Support", scope: .children(.removeItem), selected: false,
            note: "Xcode copies these again the next time you connect a device."
        ),
        ScanLocation(
            .developer, "~/Library/Developer/Xcode/iOS Device Logs",
            label: "iOS Device Logs", scope: .children(.removeItem)
        ),
        ScanLocation(
            .developer, "~/Library/Developer/Xcode/Archives",
            label: "Xcode Archives", scope: .children(.removeItem), selected: false,
            note: "Archives are needed to symbolicate crash reports from builds you shipped."
        ),
        ScanLocation(
            .developer, "~/Library/Developer/CoreSimulator/Caches",
            label: "Simulator Cache", scope: .children(.removeItem)
        ),
        ScanLocation(.developer, "~/.npm/_cacache", label: "npm Cache", scope: .contents),
        ScanLocation(
            .developer, "~/.gradle/caches", label: "Gradle Cache", scope: .contents, selected: false
        ),
        ScanLocation(
            .developer, "~/.cache", label: "Tool Cache", scope: .children(.removeItem), selected: false,
            note: "May hold large downloads, like machine learning models, that are slow to fetch again."
        )
    ]

    private static let systemLocations: [ScanLocation] = [
        ScanLocation(
            .systemCaches, "/Library/Caches", label: "System Cache", scope: .children(.removeItem), selected: false
        ),
        ScanLocation(
            .systemLogs, "/Library/Logs", label: "System Logs", scope: .children(.removeContents), selected: false
        ),
        ScanLocation(
            .systemLogs, "/private/var/log", label: "Unix Logs", scope: .children(.removeContents), selected: false,
            note: "Includes install and system logs that can help diagnose problems."
        )
    ]
}
