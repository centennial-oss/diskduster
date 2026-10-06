//
//  Scanner.swift
//  DiskDuster
//

import Foundation

nonisolated struct ScanProgress: Sendable, Equatable {
    var message: String
    var completed = 0
    var total = 0

    var fraction: Double? {
        total > 0 ? Double(completed) / Double(total) : nil
    }
}

nonisolated struct ScanResult: Sendable {
    var items: [CleanupItem] = []
    /// Folders that exist but could not be listed.
    var unreadablePaths: [String] = []
    /// Locations not scanned because DiskDuster does not have Full Disk Access.
    var skippedLocations: [ScanLocation] = []
}

/// Finds cleanup items in the catalog's locations and measures them. Runs off the main actor.
nonisolated struct Scanner: Sendable {
    let locations: [ScanLocation]
    let environment: ScanEnvironment
    /// Installed apps used to attribute items to their owners. Built from the real Applications folders when nil.
    var appDirectory: AppDirectory?

    private static let maxConcurrentMeasurements = 6
    private static let skippedNames: Set<String> = [".DS_Store", ".localized"]

    @concurrent
    func scan(progress: @escaping @MainActor @Sendable (ScanProgress) -> Void) async -> ScanResult {
        await progress(ScanProgress(message: "Looking for reclaimable files…"))
        var result = discoverCandidates()
        let candidates = result.items
        result.items = []
        guard !Task.isCancelled else { return result }

        let total = candidates.count
        await progress(ScanProgress(message: "Measuring…", completed: 0, total: total))
        result.items = await measure(candidates) { completed, latest in
            await progress(ScanProgress(message: latest, completed: completed, total: total))
        }
        result.items.sort { $0.size > $1.size }
        return result
    }

    /// Lists every candidate item without measuring it.
    func discoverCandidates() -> ScanResult {
        var result = ScanResult()
        var seen = Set<FileIdentity>()
        let apps = appDirectory ?? AppDirectory.scan(homePath: environment.homePath)
        for location in locations {
            if Task.isCancelled { break }
            if location.needsFullDiskAccess && !environment.hasFullDiskAccess {
                result.skippedLocations.append(location)
                continue
            }
            for root in PathResolver.expand(location.pattern, in: environment) {
                for var candidate in candidates(in: root, for: location, unreadable: &result.unreadablePaths) {
                    guard let identity = PathResolver.fileIdentity(candidate.path),
                          seen.insert(identity).inserted else { continue }
                    candidate.owningApp = apps.owner(of: candidate.ownerName)
                    result.items.append(candidate)
                }
            }
        }
        return result
    }

    private func candidates(
        in root: ResolvedRoot, for location: ScanLocation, unreadable: inout [String]
    ) -> [CleanupItem] {
        switch location.scope {
        case .contents:
            guard isAllowed(path: root.path, owner: root.ownerName) else { return [] }
            return [makeItem(root.path, root: root.path, owner: root.ownerName, mode: .removeContents, location)]
        case .children(let directoryMode):
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else {
                unreadable.append(root.path)
                return []
            }
            return names.sorted().compactMap { name in
                guard !Self.skippedNames.contains(name), PathResolver.isSafeComponent(name) else { return nil }
                let path = root.path + "/" + name
                guard isAllowed(path: path, owner: name) else { return nil }
                let mode = PathResolver.isRealDirectory(path) ? directoryMode : .removeItem
                return makeItem(path, root: root.path, owner: name, mode: mode, location)
            }
        }
    }

    private func isAllowed(path: String, owner: String) -> Bool {
        !environment.ignoredPaths.contains(path) && !LocationCatalog.protectedNames.contains(owner)
    }

    private func makeItem(
        _ path: String, root: String, owner: String, mode: CleanMode, _ location: ScanLocation
    ) -> CleanupItem {
        CleanupItem(
            path: path,
            rootPath: root,
            locationID: location.id,
            category: location.category,
            cleanMode: mode,
            ownerName: owner,
            locationLabel: location.label,
            size: 0,
            sizeIsPartial: false,
            requiresAdmin: location.requiresAdmin,
            alwaysPermanent: location.alwaysPermanent,
            selectedByDefault: location.selectedByDefault,
            note: location.note
        )
    }

    /// Measures candidates in parallel and drops the ones that take no space.
    private func measure(
        _ candidates: [CleanupItem],
        report: (Int, String) async -> Void
    ) async -> [CleanupItem] {
        await withTaskGroup(of: CleanupItem.self) { group in
            var pending = candidates.makeIterator()
            for _ in 0..<Self.maxConcurrentMeasurements {
                guard let next = pending.next() else { break }
                group.addTask { Self.measured(next) }
            }
            var measured: [CleanupItem] = []
            var completed = 0
            while let item = await group.next() {
                completed += 1
                if item.size > 0 { measured.append(item) }
                var started = false
                if !Task.isCancelled, let next = pending.next() {
                    group.addTask { Self.measured(next) }
                    started = true
                }
                let remaining = candidates.count - completed
                if !started && remaining > 0 {
                    // Only the biggest folders tend to be left at the end; say so rather than look stuck.
                    let what = remaining == 1 ? "large folder" : "\(remaining) large folders"
                    await report(completed, "Finishing up the last \(what)…")
                } else if completed.isMultiple(of: 8) || remaining == 0 {
                    await report(completed, item.displayPath)
                }
            }
            return measured
        }
    }

    private static func measured(_ item: CleanupItem) -> CleanupItem {
        var copy = item
        let size = DirectorySizer.allocatedSize(atPath: item.path)
        copy.size = size.bytes
        copy.sizeIsPartial = size.isPartial
        return copy
    }
}
