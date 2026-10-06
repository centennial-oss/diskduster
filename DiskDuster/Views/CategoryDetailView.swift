//
//  CategoryDetailView.swift
//  DiskDuster
//

import SwiftUI

struct CategoryDetailView: View {
    @Environment(AppModel.self) private var model
    let category: CleanupCategory
    @State private var sortOrder = [KeyPathComparator(\CleanupItem.size, order: .reverse)]
    @State private var highlighted = Set<CleanupItem.ID>()

    var body: some View {
        let rows = model.items(in: category).sorted(using: sortOrder)
        VStack(alignment: .leading, spacing: 0) {
            header(count: rows.count)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            Divider()
            if rows.isEmpty {
                emptyState
            } else {
                table(rows)
            }
        }
        .navigationTitle(category.title)
    }

    private func header(count: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            CategoryCheckbox(category: category)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.title2.weight(.semibold))
                Text(category.summary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(ByteFormat.string(model.totalBytes(in: category)))
                    .font(.title2.weight(.semibold))
                Text("\(count) items · \(ByteFormat.selected(model.selectedBytes(in: category)))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.scannedCategories.contains(category) {
            ContentUnavailableView(
                "Nothing to Clean",
                systemImage: "sparkles",
                description: Text("DiskDuster didn't find anything here.")
            )
        } else {
            ContentUnavailableView {
                Label("Not Scanned Yet", systemImage: category.symbol)
            } description: {
                Text("Rescan to include \(category.title).")
            } actions: {
                Button("Rescan") { model.startScan() }
            }
        }
    }

    private func table(_ rows: [CleanupItem]) -> some View {
        Table(rows, selection: $highlighted, sortOrder: $sortOrder) {
            TableColumn("") { item in
                Toggle(isOn: Binding(
                    get: { model.isSelected(item) },
                    set: { model.setSelected($0, item: item) }
                )) {
                    EmptyView()
                }
                .toggleStyle(.roundedCheckbox)
                .disabled(model.settings.isPreserved(item))
            }
            .width(22)
            TableColumn("Name", value: \.ownerName) { item in
                ItemNameCell(item: item, isPreserved: model.settings.isPreserved(item))
            }
            .width(min: 180, ideal: 260)
            TableColumn("Location", value: \.path) { item in
                Text(item.displayPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.path)
            }
            .width(min: 160, ideal: 320)
            TableColumn("Size", value: \.size) { item in
                Text(ByteFormat.string(item.size, partial: item.sizeIsPartial))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .help(item.sizeIsPartial ? "Some of this item couldn't be read, so it may be larger." : "")
            }
            .width(min: 70, ideal: 90, max: 120)
        }
        .contextMenu(forSelectionType: CleanupItem.ID.self) { ids in
            if !ids.isEmpty {
                Button("Reveal in Finder") { model.revealInFinder(ids) }
                Button("Copy Path") { model.copyPaths(ids) }
                Divider()
                preserveButton(for: ids)
                Button("Always Ignore") { model.ignore(ids) }
            }
        } primaryAction: { ids in
            model.revealInFinder(ids)
        }
    }
}

extension CategoryDetailView {
    /// Offers to preserve (or stop preserving) the app behind a single right-clicked row.
    @ViewBuilder
    fileprivate func preserveButton(for ids: Set<CleanupItem.ID>) -> some View {
        if ids.count == 1, let id = ids.first, let item = model.items(in: category).first(where: { $0.id == id }),
           let group = model.group(for: item) {
            if model.isPreserved(group) {
                Button("Stop Preserving \(group.name)") { model.setPreserved(false, group: group) }
            } else {
                Button("Preserve All \(group.name) Files") { model.setPreserved(true, group: group) }
            }
        }
    }
}

private struct ItemNameCell: View {
    let item: CleanupItem
    let isPreserved: Bool

    var body: some View {
        let identity = AppIdentityCache.shared
        HStack(spacing: 8) {
            Image(nsImage: identity.icon(for: item))
                .resizable()
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(identity.displayName(for: item))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if isPreserved {
                Label("Preserved", systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .help("This app is preserved, so its files are never cleaned")
            } else if item.requiresAdmin || item.alwaysPermanent {
                Image(systemName: item.requiresAdmin ? "lock.fill" : "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(item.requiresAdmin
                        ? "Deleted permanently after you enter an administrator password"
                        : "Deleted permanently")
            }
        }
        .help(item.note ?? "")
    }

    private var subtitle: String {
        item.cleanMode == .removeContents ? "\(item.locationLabel) · contents" : item.locationLabel
    }
}
