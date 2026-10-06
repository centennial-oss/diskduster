//
//  AppModel.swift
//  DiskDuster
//

import AppKit
import Foundation
import Observation

nonisolated enum SelectionState: Sendable {
    case none, some, all
}

struct CleanReport: Identifiable {
    let id = UUID()
    let outcome: CleanOutcome
    let availableBefore: Int64?
    let availableAfter: Int64?

    /// How much free space actually changed, which can differ from the estimate because of APFS clones,
    /// local snapshots and items that went to the Trash.
    var measuredChange: Int64? {
        guard let availableBefore, let availableAfter else { return nil }
        return availableAfter - availableBefore
    }
}

/// App-wide state: scan results, the user's selection, and the scan/clean lifecycle.
@Observable
final class AppModel {
    enum Phase: Equatable {
        case idle
        case scanning(ScanProgress)
        case ready
        case cleaning(String)
    }

    let settings: AppSettings
    private(set) var phase: Phase = .idle
    private(set) var items: [CleanupItem] = []
    var selectedIDs: Set<String> = []
    private(set) var scannedCategories: Set<CleanupCategory> = []
    private(set) var skippedLocations: [ScanLocation] = []
    private(set) var unreadablePaths: [String] = []
    private(set) var hasFullDiskAccess = FullDiskAccess.isGranted()
    private(set) var volume = VolumeInfo.forHomeVolume()
    private(set) var lastScanDate: Date?
    var isConfirmingClean = false
    var report: CleanReport?
    private var work: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    var isBusy: Bool {
        switch phase {
        case .scanning, .cleaning: true
        case .idle, .ready: false
        }
    }

    // MARK: - Derived results

    /// Items in categories that are currently enabled. Disabling a category hides its items immediately.
    var visibleItems: [CleanupItem] {
        items.filter { settings.isEnabled($0.category) }
    }

    var visibleCategories: [CleanupCategory] {
        CleanupCategory.allCases.filter { settings.isEnabled($0) }
    }

    /// Never includes items from preserved apps, whatever the selection says.
    var selectedItems: [CleanupItem] {
        visibleItems.filter { selectedIDs.contains($0.id) && !settings.isPreserved($0) }
    }

    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    var totalBytes: Int64 { visibleItems.reduce(0) { $0 + $1.size } }

    /// The administrator prompt is only needed when the selection includes system items.
    var selectionNeedsAdmin: Bool { selectedItems.contains { $0.requiresAdmin } }

    func items(in category: CleanupCategory) -> [CleanupItem] {
        visibleItems.filter { $0.category == category }
    }

    func totalBytes(in category: CleanupCategory) -> Int64 {
        items(in: category).reduce(0) { $0 + $1.size }
    }

    func selectedBytes(in category: CleanupCategory) -> Int64 {
        selectedItems.filter { $0.category == category }.reduce(0) { $0 + $1.size }
    }

    /// Items in a category that can be selected, which excludes preserved apps.
    func selectableItems(in category: CleanupCategory) -> [CleanupItem] {
        items(in: category).filter { !settings.isPreserved($0) }
    }

    func selectionState(of category: CleanupCategory) -> SelectionState {
        let ids = selectableItems(in: category).map(\.id)
        let selected = ids.filter { selectedIDs.contains($0) }.count
        if selected == 0 { return .none }
        return selected == ids.count ? .all : .some
    }

    func setSelected(_ selected: Bool, category: CleanupCategory) {
        let ids = Set(selectableItems(in: category).map(\.id))
        if selected {
            selectedIDs.formUnion(ids)
        } else {
            selectedIDs.subtract(ids)
        }
    }

    func isSelected(_ item: CleanupItem) -> Bool { selectedIDs.contains(item.id) && !settings.isPreserved(item) }

    func setSelected(_ selected: Bool, item: CleanupItem) {
        if selected {
            guard !settings.isPreserved(item) else { return }
            selectedIDs.insert(item.id)
        } else {
            selectedIDs.remove(item.id)
        }
    }

    // MARK: - Actions

    func refreshSystemState() {
        hasFullDiskAccess = FullDiskAccess.isGranted()
        volume = VolumeInfo.forHomeVolume()
    }

    private func makeEnvironment() -> ScanEnvironment {
        ScanEnvironment.current(hasFullDiskAccess: hasFullDiskAccess, ignoredPaths: Set(settings.ignoredPaths))
    }

    func startScan() {
        guard !isBusy else { return }
        refreshSystemState()
        let locations = settings.enabledLocations
        let scanner = Scanner(locations: locations, environment: makeEnvironment())
        phase = .scanning(ScanProgress(message: "Starting…"))
        work = Task {
            let result = await scanner.scan { progress in
                self.updateScanProgress(progress)
            }
            guard !Task.isCancelled else { return }
            apply(result, categories: Set(locations.map(\.category)))
        }
    }

    func cancelScan() {
        guard case .scanning = phase else { return }
        work?.cancel()
        work = nil
        phase = lastScanDate == nil ? .idle : .ready
    }

    private func updateScanProgress(_ progress: ScanProgress) {
        guard case .scanning = phase else { return }
        phase = .scanning(progress)
    }

    func apply(_ result: ScanResult, categories: Set<CleanupCategory>) {
        // Keep the user's choices for items seen before; use defaults for new ones.
        let previousIDs = Set(items.map(\.id))
        let previousSelection = selectedIDs
        items = result.items
        selectedIDs = Set(result.items.filter { item in
            guard !settings.isPreserved(item) else { return false }
            return previousIDs.contains(item.id) ? previousSelection.contains(item.id) : item.selectedByDefault
        }.map(\.id))
        scannedCategories = categories
        skippedLocations = result.skippedLocations
        unreadablePaths = result.unreadablePaths
        lastScanDate = .now
        phase = .ready
    }

    func requestClean() {
        guard !isBusy, !selectedItems.isEmpty else { return }
        isConfirmingClean = true
    }

    func performClean() {
        isConfirmingClean = false
        let toClean = selectedItems.filter { !settings.isPreserved($0) }
        guard !isBusy, !toClean.isEmpty else { return }
        let cleaner = Cleaner(mode: settings.deletionMode, environment: makeEnvironment())
        let availableBefore = VolumeInfo.forHomeVolume()?.availableBytes
        phase = .cleaning("Preparing…")
        work = Task {
            let outcome = await cleaner.clean(toClean) { message in
                self.updateCleanProgress(message)
            }
            volume = VolumeInfo.forHomeVolume()
            let cleanedIDs = Set(outcome.cleaned.map(\.id))
            items.removeAll { cleanedIDs.contains($0.id) }
            selectedIDs.subtract(cleanedIDs)
            phase = .ready
            report = CleanReport(
                outcome: outcome, availableBefore: availableBefore, availableAfter: volume?.availableBytes
            )
        }
    }

    private func updateCleanProgress(_ message: String) {
        guard case .cleaning = phase else { return }
        phase = .cleaning(message)
    }

    // MARK: - Apps

    /// Every app (or unattributed folder) that owns scan results, largest first.
    var appGroups: [AppGroup] {
        Dictionary(grouping: visibleItems, by: \.appKey)
            .map { key, items in AppGroup(key: key, items: items) }
            .sorted { $0.totalBytes > $1.totalBytes }
    }

    func isPreserved(_ group: AppGroup) -> Bool {
        settings.preservedApps[group.key] != nil
    }

    /// Preserving unchecks the app's items everywhere; un-preserving restores their default selection.
    func setPreserved(_ preserved: Bool, group: AppGroup) {
        if preserved {
            settings.preservedApps[group.key] = group.name
            selectedIDs.subtract(group.items.map(\.id))
        } else {
            settings.preservedApps[group.key] = nil
            selectedIDs.formUnion(group.items.filter(\.selectedByDefault).map(\.id))
        }
    }

    func group(for item: CleanupItem) -> AppGroup? {
        appGroups.first { $0.key == item.appKey }
    }

    func ignore(_ ids: Set<String>) {
        for id in ids { settings.ignore(id) }
        items.removeAll { ids.contains($0.id) }
        selectedIDs.subtract(ids)
    }

    func revealInFinder(_ ids: Set<String>) {
        let urls = items.filter { ids.contains($0.id) }.map(\.url)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func copyPaths(_ ids: Set<String>) {
        let paths = items.filter { ids.contains($0.id) }.map(\.path)
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    func openFullDiskAccessSettings() {
        if let url = FullDiskAccess.settingsURL {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Everything one app owns across all categories.
nonisolated struct AppGroup: Identifiable, Sendable {
    let key: String
    let items: [CleanupItem]
    let name: String
    let totalBytes: Int64
    let categories: [CleanupCategory]

    init(key: String, items: [CleanupItem]) {
        self.key = key
        self.items = items
        name = items.first?.owningApp?.name ?? items.first?.ownerName ?? key
        totalBytes = items.reduce(0) { $0 + $1.size }
        categories = CleanupCategory.allCases.filter { category in items.contains { $0.category == category } }
    }

    var id: String { key }
    var app: InstalledApp? { items.first?.owningApp }
    var itemCount: Int { items.count }
    var categorySummary: String { categories.map(\.title).formatted(.list(type: .and)) }
}
