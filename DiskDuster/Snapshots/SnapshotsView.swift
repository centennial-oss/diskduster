//
//  SnapshotsView.swift
//  DiskDuster
//

import SwiftUI

struct SnapshotsView: View {
    @Environment(SnapshotsController.self) private var controller

    var body: some View {
        @Bindable var controller = controller
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if controller.hasLoaded && controller.snapshots.isEmpty {
                    ContentUnavailableView(
                        "No Local Snapshots",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Time Machine isn't holding any snapshots on this Mac right now.")
                    )
                    .padding(.vertical, 40)
                } else if !controller.hasLoaded {
                    ProgressView("Looking for snapshots…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    snapshotList
                }
                notes
            }
            .padding(28)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Time Machine Snapshots")
        .onAppear { controller.refresh() }
        .sheet(isPresented: $controller.isConfirming) { ConfirmSnapshotDeletionSheet() }
        .sheet(item: $controller.report) { report in SnapshotReportSheet(report: report) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Machine Snapshots")
                    .font(.largeTitle.weight(.bold))
                Text("Time Machine keeps local snapshots of your disk between backups. Files you delete stay on "
                    + "disk until every snapshot that includes them is gone.")
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private var snapshotList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Snapshots on This Mac").font(.title3.weight(.semibold))
                Spacer()
                BasicButton("All", prominence: .secondary, size: .small) {
                    controller.selection = Set(controller.snapshots.map(\.id))
                }
                BasicButton("None", prominence: .secondary, size: .small) { controller.selection = [] }
            }
            VStack(spacing: 0) {
                ForEach(controller.snapshots) { snapshot in
                    row(snapshot)
                    if snapshot != controller.snapshots.last { Divider().padding(.leading, 44) }
                }
            }
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
    }

    private func row(_ snapshot: LocalSnapshot) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { controller.selection.contains(snapshot.id) },
                set: { isOn in
                    if isOn {
                        controller.selection.insert(snapshot.id)
                    } else {
                        controller.selection.remove(snapshot.id)
                    }
                }
            )) { EmptyView() }
                .toggleStyle(.roundedCheckbox)
            Image(systemName: "externaldrive.badge.timemachine")
                .foregroundStyle(.tint)
                .frame(width: 20)
            Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
            Text("– \(snapshot.date.formatted(.relative(presentation: .named)))")
                .foregroundStyle(.secondary)
            Spacer()
            Text(snapshot.dateStamp)
                .font(.callout.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("macOS doesn't report how much space each snapshot holds. DiskDuster shows how much was freed "
                + "after deleting.", systemImage: "questionmark.circle")
            Label("Back up with Time Machine first, so your latest changes are safe on your backup disk.",
                  systemImage: "externaldrive.badge.checkmark")
            Label("Deleting snapshots needs your administrator password and can't be undone.",
                  systemImage: "lock")
            Label("Time Machine keeps making new snapshots, usually every hour while a backup disk is set up.",
                  systemImage: "clock")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
