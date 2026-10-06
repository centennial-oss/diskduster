//
//  AppSettings.swift
//  DiskDuster
//

import Foundation
import Observation

/// User preferences, persisted in UserDefaults.
@Observable
final class AppSettings {
    private enum Key {
        static let deletionMode = "deletionMode"
        static let includeSystemLocations = "includeSystemLocations"
        static let disabledCategories = "disabledCategories"
        static let ignoredPaths = "ignoredPaths"
        static let preservedApps = "preservedApps"
    }

    private let defaults: UserDefaults

    var deletionMode: DeletionMode {
        didSet { defaults.set(deletionMode.rawValue, forKey: Key.deletionMode) }
    }

    /// When off, DiskDuster only looks inside the home folder and never asks for an administrator password.
    var includeSystemLocations: Bool {
        didSet { defaults.set(includeSystemLocations, forKey: Key.includeSystemLocations) }
    }

    var disabledCategories: Set<CleanupCategory> {
        didSet { defaults.set(disabledCategories.map(\.rawValue).sorted(), forKey: Key.disabledCategories) }
    }

    /// Paths the user chose to always skip.
    var ignoredPaths: [String] {
        didSet { defaults.set(ignoredPaths, forKey: Key.ignoredPaths) }
    }

    /// Apps whose files are never cleaned, keyed by `CleanupItem.appKey`, with the name shown to the user.
    var preservedApps: [String: String] {
        didSet { defaults.set(preservedApps, forKey: Key.preservedApps) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        deletionMode = DeletionMode(rawValue: defaults.string(forKey: Key.deletionMode) ?? "") ?? .trash
        includeSystemLocations = defaults.object(forKey: Key.includeSystemLocations) as? Bool ?? true
        let disabled = defaults.stringArray(forKey: Key.disabledCategories) ?? []
        disabledCategories = Set(disabled.compactMap(CleanupCategory.init(rawValue:)))
        ignoredPaths = defaults.stringArray(forKey: Key.ignoredPaths) ?? []
        preservedApps = defaults.dictionary(forKey: Key.preservedApps) as? [String: String] ?? [:]
    }

    func isPreserved(_ item: CleanupItem) -> Bool {
        preservedApps[item.appKey] != nil
    }

    func isEnabled(_ category: CleanupCategory) -> Bool {
        if category.requiresAdmin && !includeSystemLocations { return false }
        return !disabledCategories.contains(category)
    }

    func setEnabled(_ category: CleanupCategory, _ enabled: Bool) {
        if enabled {
            disabledCategories.remove(category)
        } else {
            disabledCategories.insert(category)
        }
    }

    var enabledLocations: [ScanLocation] {
        LocationCatalog.all.filter { isEnabled($0.category) }
    }

    func ignore(_ path: String) {
        guard !ignoredPaths.contains(path) else { return }
        ignoredPaths.append(path)
        ignoredPaths.sort()
    }

    func unignore(_ path: String) {
        ignoredPaths.removeAll { $0 == path }
    }
}
