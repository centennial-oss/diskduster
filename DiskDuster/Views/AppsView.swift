//
//  AppsView.swift
//  DiskDuster
//

import SwiftUI

/// Scan results grouped by the app that owns them, so a whole app can be preserved in one click.
struct AppsView: View {
    nonisolated enum Scope: String, CaseIterable, Identifiable, Sendable {
        case apps, otherFolders, all
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @State private var searchText = ""
    @State private var scope: Scope = .apps
    @State private var sortOrder = [KeyPathComparator(\AppGroup.totalBytes, order: .reverse)]
    @State private var highlighted = Set<AppGroup.ID>()

    var body: some View {
        let groups = matching(model.appGroups)
        let apps = groups.filter { $0.app != nil }
        let folders = groups.filter { $0.app == nil }
        let rows = rows(for: scope, apps: apps, folders: folders, all: groups).sorted(using: sortOrder)
        VStack(alignment: .leading, spacing: 0) {
            header(appCount: apps.count, folderCount: folders.count, allCount: groups.count)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            Divider()
            table(rows)
                .overlay {
                    if rows.isEmpty {
                        if searchText.isEmpty {
                            ContentUnavailableView("Nothing Here", systemImage: "square.grid.2x2")
                        } else {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                }
        }
        .searchable(text: $searchText, prompt: "Search apps")
        .navigationTitle("Apps")
    }

    private func header(appCount: Int, folderCount: Int, allCount: Int) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // No vertical fixedSize here: outside a ScrollView it inflates the window's minimum height.
            Text("Preserve an app to keep all of its caches, logs and other files, in every category. "
                + "DiskDuster remembers your choice for future scans.")
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            GlassSegmentedControl(selection: $scope, options: [
                .init(value: .apps, title: "Apps (\(appCount))"),
                .init(value: .otherFolders, title: "Other Folders (\(folderCount))"),
                .init(value: .all, title: "All (\(allCount))")
            ])
            .fixedSize()
            .help("Other Folders are ones DiskDuster couldn't match to an installed app")
        }
    }

    private func table(_ rows: [AppGroup]) -> some View {
        Table(rows, selection: $highlighted, sortOrder: $sortOrder) {
            TableColumn("Preserve") { group in
                Toggle("Preserve", isOn: preservedBinding(group))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.mini)
                    .help("Never clean \(group.name)'s files")
            }
            .width(60)
            TableColumn("Name", value: \.name, comparator: .localizedStandard) { group in
                AppNameCell(group: group, isPreserved: model.isPreserved(group))
            }
            .width(min: 180, ideal: 280)
            TableColumn("Found In", value: \.categorySummary, comparator: .localizedStandard) { group in
                Text(group.categorySummary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(group.categorySummary)
            }
            .width(min: 140, ideal: 260)
            TableColumn("Items", value: \.itemCount) { group in
                Text("\(group.itemCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 44, ideal: 56, max: 80)
            TableColumn("Size", value: \.totalBytes) { group in
                Text(ByteFormat.string(group.totalBytes))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 120)
        }
        .contextMenu(forSelectionType: AppGroup.ID.self) { ids in
            contextMenu(for: ids)
        }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<AppGroup.ID>) -> some View {
        let selected = model.appGroups.filter { ids.contains($0.id) }
        if !selected.isEmpty {
            let allPreserved = selected.allSatisfy { model.isPreserved($0) }
            let label = selected.count == 1 ? selected[0].name : "\(selected.count) Apps"
            Button(allPreserved ? "Stop Preserving \(label)" : "Preserve \(label)") {
                for group in selected { model.setPreserved(!allPreserved, group: group) }
            }
            Divider()
            Button("Reveal in Finder") { model.revealInFinder(Set(selected.flatMap(\.items).map(\.id))) }
        }
    }

    private func preservedBinding(_ group: AppGroup) -> Binding<Bool> {
        Binding(get: { model.isPreserved(group) }, set: { model.setPreserved($0, group: group) })
    }

    private func rows(for scope: Scope, apps: [AppGroup], folders: [AppGroup], all: [AppGroup]) -> [AppGroup] {
        switch scope {
        case .apps: apps
        case .otherFolders: folders
        case .all: all
        }
    }

    private func matching(_ groups: [AppGroup]) -> [AppGroup] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return groups }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(query)
                || group.items.contains { $0.ownerName.localizedCaseInsensitiveContains(query) }
        }
    }
}

private struct AppNameCell: View {
    let group: AppGroup
    let isPreserved: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let first = group.items.first {
                Image(nsImage: AppIdentityCache.shared.icon(for: first))
                    .resizable()
                    .frame(width: 18, height: 18)
            }
            Text(group.name)
                .lineLimit(1)
            if isPreserved {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Preserved: never cleaned")
            }
        }
    }
}
