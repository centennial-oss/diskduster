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
    case appleIntelligence
    case snapshots
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppleIntelligenceController.self) private var intelligence
    @Environment(SnapshotsController.self) private var snapshots
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
        .sheet(isPresented: $model.isShowingAbout) {
            AboutView { model.isShowingAbout = false }
                .interactiveDismissDisabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if !model.isBusy { model.refreshSystemState() }
        }
        .task {
            intelligence.refresh()
            snapshots.refresh()
        }
        #if DEBUG
        .task { applyDebugLaunchArguments() }
        #endif
    }

    #if DEBUG
    /// Debug-only hooks for screenshots and manual testing, e.g.
    /// `open DiskDuster.app --args -DDAutoScan YES -DDSidebar userCaches` (or `apps`, `appleIntelligence`).
    private func applyDebugLaunchArguments() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "DDSidebar") {
            switch raw {
            case "apps": sidebarSelection = .apps
            case "appleIntelligence": sidebarSelection = .appleIntelligence
            case "snapshots": sidebarSelection = .snapshots
            default: sidebarSelection = CleanupCategory(rawValue: raw).map { .category($0) }
            }
        }
        if defaults.bool(forKey: "DDAutoScan") { model.startScan() }
        if defaults.bool(forKey: "DDShowAbout") { model.isShowingAbout = true }
        // Opens the confirmation sheet once the scan finishes. It never cleans by itself.
        if defaults.bool(forKey: "DDShowConfirm") {
            Task {
                while model.phase != .ready { try? await Task.sleep(for: .seconds(1)) }
                model.requestClean()
            }
        }
    }
    #endif

    @ViewBuilder
    private var detail: some View {
        switch model.phase {
        case .idle where sidebarSelection == .appleIntelligence:
            // The tools don't depend on a scan, so they're available right away.
            AppleIntelligenceView()
        case .idle where sidebarSelection == .snapshots:
            SnapshotsView()
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
            case .appleIntelligence:
                AppleIntelligenceView()
            case .snapshots:
                SnapshotsView()
            case .overview, nil:
                OverviewView { sidebarSelection = .category($0) }
            }
        }
    }

    private var cleanTitle: String {
        model.selectedBytes > 0 ? "Clean \(ByteFormat.string(model.selectedBytes))" : "Clean"
    }

    private var showsAppleIntelligence: Bool {
        sidebarSelection == .appleIntelligence && intelligence.isPlatformSupported
    }

    private var showsSnapshots: Bool { sidebarSelection == .snapshots }

    /// The toolbar acts on whatever the window is showing: each tool gets its own rescan and main action, and
    /// the disk clean is everywhere else, so the main action is never below the fold.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if showsAppleIntelligence {
                rescanButton(help: "Check Apple Intelligence again") { intelligence.refresh() }
                    .disabled(intelligence.isBusy || intelligence.isRefreshing)
            } else if showsSnapshots {
                rescanButton(help: "Look for Time Machine snapshots again") { snapshots.refresh() }
                    .disabled(snapshots.isBusy)
            } else {
                rescanButton(title: model.lastScanDate == nil ? "Scan" : "Rescan",
                             help: "Scan for reclaimable files (⌘R)") { model.startScan() }
                    .disabled(model.isBusy)
            }
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            if showsAppleIntelligence {
                mainButton(intelligence.actionTitle, symbol: intelligence.actionSymbol,
                           help: intelligence.actionHelp) { intelligence.performPrimaryAction() }
                    .disabled(!intelligence.canPerformPrimaryAction)
            } else if showsSnapshots {
                mainButton(snapshots.actionTitle, symbol: "trash",
                           help: "Delete the selected Time Machine snapshots") { snapshots.requestDelete() }
                    .disabled(!snapshots.canDelete)
            } else {
                mainButton(cleanTitle, symbol: "sparkles",
                           help: "Review and clean the selected items") { model.requestClean() }
                    .disabled(model.isBusy || model.selectedItems.isEmpty)
            }
        }
    }

    private func rescanButton(title: String = "Rescan", help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "arrow.clockwise")
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 6)
        }
        .help(help)
    }

    private func mainButton(_ title: String, symbol: String, help: String, action: @escaping () -> Void)
        -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .modifier(ProminentLabelColor())
        }
        .buttonStyle(.borderedProminent)
        .help(help)
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppleIntelligenceController.self) private var intelligence
    @Environment(SnapshotsController.self) private var snapshots
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
            Section("Tools") {
                if intelligence.isPlatformSupported {
                    HStack {
                        Label("Apple Intelligence", systemImage: "apple.intelligence")
                        Spacer()
                        Text(intelligence.snapshot?.totalModelBytes.map { ByteFormat.string($0) } ?? "")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .tag(SidebarItem.appleIntelligence)
                }
                HStack {
                    Label("Time Machine Snapshots", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    if snapshots.hasLoaded {
                        Text("\(snapshots.snapshots.count)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .tag(SidebarItem.snapshots)
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
