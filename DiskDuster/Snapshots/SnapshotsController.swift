//
//  SnapshotsController.swift
//  DiskDuster
//

import Foundation
import Observation

nonisolated struct SnapshotReport: Identifiable, Sendable {
    let id = UUID()
    let deletion: SnapshotDeletion
    let availableBefore: Int64?
    let availableAfter: Int64?

    var freedBytes: Int64? {
        guard let availableBefore, let availableAfter else { return nil }
        return availableAfter - availableBefore
    }
}

/// Drives the Time Machine Snapshots screen: listing, selecting, backing up first, and deleting as root.
@Observable
final class SnapshotsController {
    private(set) var snapshots: [LocalSnapshot] = []
    var selection: Set<LocalSnapshot.ID> = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isDeleting = false
    private(set) var hasBackupDisk = false
    /// Back up to Time Machine before deleting. Checked by default whenever a backup disk is set up.
    var backUpFirst = true
    /// What the deletion is doing right now, shown in the confirmation sheet while it runs.
    private(set) var status: String?
    /// Why the last attempt stopped before deleting anything.
    private(set) var problem: String?
    var isConfirming = false
    var report: SnapshotReport?
    private var work: Task<Void, Never>?

    var selectedSnapshots: [LocalSnapshot] {
        snapshots.filter { selection.contains($0.id) }
    }

    var isBusy: Bool { isLoading || isDeleting }

    var actionTitle: String {
        let count = selectedSnapshots.count
        return count == 1 ? "Delete 1 Snapshot" : "Delete \(count) Snapshots"
    }

    var canDelete: Bool { !selectedSnapshots.isEmpty && !isBusy }

    func refresh() {
        guard !isBusy else { return }
        isLoading = true
        Task {
            let found = await SnapshotService.list()
            let backupDisk = await SnapshotService.hasBackupDestination()
            // Snapshots start unchecked so deleting is always a deliberate choice; keep the user's choices for
            // snapshots that are still there.
            selection = selection.intersection(found.map(\.id))
            snapshots = found
            hasBackupDisk = backupDisk
            hasLoaded = true
            isLoading = false
        }
    }

    func requestDelete() {
        guard canDelete else { return }
        problem = nil
        isConfirming = true
    }

    var confirmTitle: String {
        backUpFirst && hasBackupDisk ? "Back Up and Delete" : "Delete Snapshots"
    }

    /// Optionally backs up to Time Machine and waits for it to finish, then deletes the selected snapshots
    /// after one administrator prompt. The confirmation sheet stays open to show progress.
    func performDelete() {
        let chosen = selectedSnapshots
        guard !chosen.isEmpty, !isBusy else { return }
        let backingUp = backUpFirst && hasBackupDisk
        isDeleting = true
        problem = nil
        work = Task {
            if backingUp {
                guard await backUp() else {
                    guard !Task.isCancelled else { return }
                    finishWithoutDeleting(problem: "Time Machine couldn't start a backup, so nothing was deleted. "
                        + "Try again, or uncheck the backup option.")
                    return
                }
            }
            guard !Task.isCancelled else { return }
            status = "Waiting for your administrator password…"
            let before = VolumeInfo.forHomeVolume()?.availableBytes
            let deletion = await SnapshotService.delete(chosen)
            status = "Measuring freed space…"
            // APFS releases snapshot space a moment after the snapshot is gone.
            try? await Task.sleep(for: .seconds(2))
            let after = VolumeInfo.forHomeVolume()?.availableBytes
            isConfirming = false
            status = nil
            isDeleting = false
            // Let the confirmation sheet close before the report sheet opens.
            try? await Task.sleep(for: .milliseconds(400))
            report = SnapshotReport(deletion: deletion, availableBefore: before, availableAfter: after)
            refresh()
        }
    }

    /// Stops waiting. A backup already in progress keeps running in Time Machine; nothing is deleted.
    func cancelDelete() {
        work?.cancel()
        work = nil
        status = nil
        isDeleting = false
        isConfirming = false
    }

    private func backUp() async -> Bool {
        status = "Starting a Time Machine backup…"
        guard await SnapshotService.startBackup() else { return false }
        status = "Backing up to Time Machine. The snapshots will be deleted when the backup finishes."
        try? await Task.sleep(for: .seconds(3))
        while !Task.isCancelled, await SnapshotService.isBackupRunning() {
            try? await Task.sleep(for: .seconds(3))
        }
        return !Task.isCancelled
    }

    private func finishWithoutDeleting(problem: String) {
        self.problem = problem
        status = nil
        isDeleting = false
    }
}
