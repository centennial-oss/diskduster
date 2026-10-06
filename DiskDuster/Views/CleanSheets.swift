//
//  CleanSheets.swift
//  DiskDuster
//

import SwiftUI

/// The last stop before anything is removed: what will be cleaned, and how.
struct ConfirmCleanSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let selected = model.selectedItems
        let adminItems = selected.filter(\.requiresAdmin)
        let permanentItems = selected.filter { $0.alwaysPermanent && !$0.requiresAdmin }
        VStack(alignment: .leading, spacing: 18) {
            Text("Clean \(ByteFormat.string(model.selectedBytes))?")
                .font(.title2.weight(.bold))

            VStack(spacing: 6) {
                ForEach(model.visibleCategories) { category in
                    let items = selected.filter { $0.category == category }
                    if !items.isEmpty {
                        HStack {
                            Label(category.title, systemImage: category.symbol)
                            Spacer()
                            Text("\(items.count) items · \(ByteFormat.string(items.reduce(0) { $0 + $1.size }))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 10) {
                if settings.deletionMode == .trash {
                    note("trash", "Your files will be moved to the Trash. Space is freed when you empty it.")
                } else {
                    note("exclamationmark.triangle", "Your files will be deleted permanently.", warning: true)
                }
                if !permanentItems.isEmpty {
                    note("trash.slash", "Items already in the Trash will be deleted permanently.", warning: true)
                }
                if !adminItems.isEmpty {
                    note(
                        "lock",
                        "\(adminItems.count) system items will be deleted permanently. macOS will ask for an "
                            + "administrator password.",
                        warning: true
                    )
                }
                note("app.badge.checkmark", "For best results, quit apps you aren't using before cleaning.")
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(settings.deletionMode == .trash ? "Move to Trash" : "Delete", role: .destructive) {
                    model.performClean()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func note(_ symbol: String, _ text: String, warning: Bool = false) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(warning ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint))
        }
    }
}

/// Shows what was cleaned, what changed on disk, and anything that failed.
struct CleanReportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let report: CleanReport

    var body: some View {
        let outcome = report.outcome
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: outcome.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(outcome.failures.isEmpty ? .green : .orange)
                VStack(alignment: .leading) {
                    Text("Cleaned \(ByteFormat.string(outcome.bytesCleaned))")
                        .font(.title2.weight(.bold))
                    Text("\(outcome.cleaned.count) items cleaned")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let change = report.measuredChange, let after = report.availableAfter {
                    Text("Free space changed by \(ByteFormat.string(change)) and is now \(ByteFormat.string(after)).")
                }
                if outcome.usedTrash {
                    Text("Items moved to the Trash still use space until you empty it. Rescan to clean them from "
                        + "the Trash category.")
                }
                if outcome.adminCancelled {
                    Text("System items were skipped because the administrator prompt was cancelled.")
                }
                Text("macOS may take a moment to report freed space, and local Time Machine snapshots can "
                    + "hold on to it for a while.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

            if !outcome.failures.isEmpty {
                DisclosureGroup("\(outcome.failures.count) items could not be cleaned") {
                    List(outcome.failures) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.item.displayPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(failure.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 160)
                }
            }

            HStack {
                Spacer()
                Button("Rescan") {
                    dismiss()
                    model.startScan()
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
