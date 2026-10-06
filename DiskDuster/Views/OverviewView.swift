//
//  OverviewView.swift
//  DiskDuster
//

import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    let onOpenCategory: (CleanupCategory) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !model.hasFullDiskAccess {
                    FullDiskAccessCard()
                }
                VStack(spacing: 10) {
                    ForEach(model.visibleCategories) { category in
                        CategoryRow(category: category) { onOpenCategory(category) }
                    }
                }
                footnotes
            }
            .padding(28)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(ByteFormat.string(model.totalBytes)) can be cleaned")
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            Text("\(ByteFormat.string(model.selectedBytes)) in \(model.selectedItems.count) items selected")
                .font(.title3)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var footnotes: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.skippedLocations.isEmpty {
                Label(
                    "\(model.skippedLocations.count) locations were skipped because Full Disk Access is off.",
                    systemImage: "lock"
                )
            }
            if !model.unreadablePaths.isEmpty {
                Label("\(model.unreadablePaths.count) folders could not be read.", systemImage: "eye.slash")
                    .help(model.unreadablePaths.joined(separator: "\n"))
            }
            if !model.settings.preservedApps.isEmpty {
                let count = model.settings.preservedApps.count
                Label("\(count) preserved \(count == 1 ? "app is" : "apps are") never cleaned.", systemImage: "lock")
            }
            if let date = model.lastScanDate {
                Label("Last scanned \(date.formatted(.relative(presentation: .named)))", systemImage: "clock")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

private struct CategoryRow: View {
    @Environment(AppModel.self) private var model
    let category: CleanupCategory
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            CategoryCheckbox(category: category)
            Image(systemName: category.symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(category.title)
                        .font(.headline)
                    if category.requiresAdmin {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Requires an administrator password")
                    }
                }
                Text(category.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 3) {
                Text(ByteFormat.string(model.totalBytes(in: category)))
                    .font(.title3.weight(.semibold))
                Text(ByteFormat.selected(model.selectedBytes(in: category)))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            Button(action: onOpen) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .help("Show items in \(category.title)")
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .contentShape(.rect)
        .onTapGesture(count: 2, perform: onOpen)
    }
}
