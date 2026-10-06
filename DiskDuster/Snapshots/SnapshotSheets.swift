//
//  SnapshotSheets.swift
//  DiskDuster
//

import SwiftUI

/// Confirms deleting the selected snapshots, optionally backing up to Time Machine first in the same step.
struct ConfirmSnapshotDeletionSheet: View {
    @Environment(SnapshotsController.self) private var controller

    var body: some View {
        @Bindable var controller = controller
        let count = controller.selectedSnapshots.count
        VStack(alignment: .leading, spacing: 18) {
            Text("Delete \(count) Time Machine \(count == 1 ? "Snapshot" : "Snapshots")?")
                .font(.title2.weight(.bold))

            VStack(alignment: .leading, spacing: 12) {
                if controller.hasBackupDisk {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledSwitch(title: "Back up to Time Machine before deleting snapshots",
                                      isOn: $controller.backUpFirst)
                            .disabled(controller.isDeleting)
                        Text("Recommended. Your latest changes are saved to your backup disk first.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                } else {
                    Label("No Time Machine backup disk is set up, so these snapshots may be the only copies of "
                        + "recent changes.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Label("Deleting snapshots can't be undone. macOS will ask for your administrator password.",
                      systemImage: "lock")
                if let problem = controller.problem {
                    Label(problem, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }

            // Progress gets its own full-width line so it never competes with the buttons for space.
            if let status = controller.status {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(status)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            HStack(spacing: 12) {
                Spacer()
                BasicButton("Cancel", role: .cancel, prominence: .secondary, keyboardShortcut: .cancelAction) {
                    controller.cancelDelete()
                }
                BasicButton(controller.confirmTitle, systemImage: "trash", role: .destructive) {
                    controller.performDelete()
                }
                .disabled(controller.isDeleting)
            }
        }
        .padding(28)
        .frame(width: 640)
        .interactiveDismissDisabled(controller.isDeleting)
    }
}

struct SnapshotReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let report: SnapshotReport

    var body: some View {
        let deletion = report.deletion
        let succeeded = deletion.failed.isEmpty
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(succeeded ? .green : .orange)
                Text(headline).font(.title2.weight(.bold))
            }
            if let freed = report.freedBytes, let after = report.availableAfter {
                Text("Free space changed by \(ByteFormat.string(freed)) and is now \(ByteFormat.string(after)). "
                    + "macOS can take a few minutes to release all of it.")
            }
            if deletion.adminCancelled {
                Text("Nothing was deleted because the administrator prompt was cancelled.")
            } else if let message = deletion.errorMessage {
                Text(message).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                BasicButton("Done", keyboardShortcut: .defaultAction) { dismiss() }
            }
        }
        .padding(28)
        .frame(width: 560)
    }

    private var headline: String {
        let deleted = report.deletion.deleted.count
        let failed = report.deletion.failed.count
        if failed == 0 { return "Deleted \(deleted) \(deleted == 1 ? "Snapshot" : "Snapshots")" }
        if deleted == 0 { return "No Snapshots Deleted" }
        return "Deleted \(deleted), \(failed) Couldn't Be Deleted"
    }
}
