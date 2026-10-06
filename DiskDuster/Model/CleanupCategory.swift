//
//  CleanupCategory.swift
//  DiskDuster
//

import Foundation

/// The groups of reclaimable files that DiskDuster knows how to find.
nonisolated enum CleanupCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case userCaches
    case appCaches
    case logs
    case developer
    case trash
    case systemCaches
    case systemLogs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userCaches: "Caches"
        case .appCaches: "App Data Caches"
        case .logs: "Logs"
        case .developer: "Developer"
        case .trash: "Trash"
        case .systemCaches: "System Caches"
        case .systemLogs: "System Logs"
        }
    }

    var symbol: String {
        switch self {
        case .userCaches: "archivebox"
        case .appCaches: "app.badge"
        case .logs: "doc.text"
        case .developer: "hammer"
        case .trash: "trash"
        case .systemCaches: "externaldrive.badge.person.crop"
        case .systemLogs: "doc.text.magnifyingglass"
        }
    }

    var summary: String {
        switch self {
        case .userCaches:
            "Files apps keep to speed things up. Apps rebuild them as needed."
        case .appCaches:
            "Caches stored inside app containers and Application Support folders, such as Electron app caches."
        case .logs:
            "Diagnostic logs written by apps. Useful for troubleshooting, but safe to remove."
        case .developer:
            "Xcode build products, device support files, simulator caches and package manager caches."
        case .trash:
            "Items already in your Trash. Cleaning these deletes them permanently."
        case .systemCaches:
            "Caches shared by all users. Cleaning requires an administrator password."
        case .systemLogs:
            "System-wide logs. Cleaning requires an administrator password."
        }
    }

    /// System categories live outside the home folder and need an administrator password to clean.
    var requiresAdmin: Bool {
        self == .systemCaches || self == .systemLogs
    }
}
