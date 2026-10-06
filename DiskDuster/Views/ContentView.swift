//
//  ContentView.swift
//  DiskDuster
//

import AppKit
import SwiftUI

enum SidebarItem: Hashable {
    case overview
    case apps
    case category(CleanupCategory)
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var sidebarSelection: SidebarItem? = .overview

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 260, ideal: 270, max: 380)
        } detail: {
            detail
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $model.isConfirmingClean) {
            ConfirmCleanSheet()
        }
        .sheet(item: $model.report) { report in
            CleanReportSheet(report: report)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if !model.isBusy { model.refreshSystemState() }
        }
        #if DEBUG
        .task { applyDebugLaunchArguments() }
        #endif
    }

    #if DEBUG
    /// Debug-only hooks for screenshots and manual testing, e.g.
    /// `open DiskDuster.app --args -DDAutoScan YES -DDSidebar userCaches`.
    private func applyDebugLaunchArguments() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "DDSidebar") {
            sidebarSelection = raw == "apps" ? .apps : CleanupCategory(rawValue: raw).map { .category($0) }
        }
        if defaults.bool(forKey: "DDAutoScan") { model.startScan() }
    }
    #endif

    @ViewBuilder
    private var detail: some View {
        switch model.phase {
        case .idle:
            WelcomeView()
        case .scanning(let progress):
            ProgressPanel(
                title: "Scanning",
                message: progress.message,
                fraction: progress.fraction,
                onCancel: { model.cancelScan() }
            )
        case .cleaning(let message):
            ProgressPanel(title: "Cleaning", message: message)
        case .ready:
            switch sidebarSelection {
            case .category(let category):
                CategoryDetailView(category: category)
            case .apps:
                AppsView()
            case .overview, nil:
                OverviewView { sidebarSelection = .category($0) }
            }
        }
    }

    private var cleanTitle: String {
        model.selectedBytes > 0 ? "Clean \(ByteFormat.string(model.selectedBytes))" : "Clean"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                model.startScan()
            } label: {
                Label(model.lastScanDate == nil ? "Scan" : "Rescan", systemImage: "arrow.clockwise")
            }
            .help("Scan for reclaimable files (⌘R)")
            .disabled(model.isBusy)
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            Button {
                model.requestClean()
            } label: {
                Label(cleanTitle, systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.borderedProminent)
            .help("Review and clean the selected items")
            .disabled(model.isBusy || model.selectedItems.isEmpty)
        }
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label("Overview", systemImage: "chart.pie")
                .tag(SidebarItem.overview)
            HStack {
                Label("Apps", systemImage: "square.grid.2x2")
                    .opacity(hasResults ? 1 : 0.4)
                Spacer()
                if !model.settings.preservedApps.isEmpty {
                    Label("\(model.settings.preservedApps.count)", systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .help("Preserved apps")
                }
            }
            .tag(SidebarItem.apps)
            .selectionDisabled(!hasResults)
            Section("Categories") {
                ForEach(model.visibleCategories) { category in
                    HStack(spacing: 6) {
                        CategoryCheckbox(category: category)
                            .disabled(!hasResults)
                        Label(category.title, systemImage: category.symbol)
                            .opacity(hasResults ? 1 : 0.4)
                        Spacer()
                        Text(sizeText(for: category))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .help(hasResults ? selectionHelp(for: category) : "Scan to see what's here")
                    .tag(SidebarItem.category(category))
                    .selectionDisabled(!hasResults)
                }
            }
        }
        .disabled(model.isBusy)
        .safeAreaInset(edge: .bottom) {
            DiskUsageView()
                .padding(14)
        }
    }

    /// Everything but Overview stays disabled until the first scan finishes.
    private var hasResults: Bool { model.lastScanDate != nil }

    private func sizeText(for category: CleanupCategory) -> String {
        guard model.scannedCategories.contains(category) else { return "–" }
        return ByteFormat.string(model.totalBytes(in: category))
    }

    private func selectionHelp(for category: CleanupCategory) -> String {
        switch model.selectionState(of: category) {
        case .all: "Everything in \(category.title) will be cleaned"
        case .some: "\(ByteFormat.string(model.selectedBytes(in: category))) of \(category.title) will be cleaned"
        case .none: "Nothing in \(category.title) will be cleaned"
        }
    }
}
