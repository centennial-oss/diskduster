//
//  AppleIntelligenceController.swift
//  DiskDuster
//

import AppKit
import Foundation
import Observation

/// Drives the Apple Intelligence screen: reads the current state, walks the user through installing or
/// removing DiskDuster's profile in System Settings, and removes models once downloads are blocked.
@Observable
final class AppleIntelligenceController {
    enum Step: Equatable {
        case idle
        case waitingForInstall
        case removingModels(String)
        case waitingForRemoval
        case finished
    }

    private(set) var snapshot: AISnapshot?
    private(set) var isRefreshing = false
    /// The features the user wants off.
    var selection: Set<AIFeature> = Set(AIFeature.allCases)
    private(set) var step: Step = .idle
    private(set) var report: AIRunReport?
    var isShowingFlow = false
    private var flow: Task<Void, Never>?
    private var hasLoaded = false

    /// Hidden on Intel Macs and on macOS 26, where System Settings has its own Apple Intelligence switch.
    let isPlatformSupported = AISnapshot.isPlatformSupported

    var packsToRemove: [AIModelPack] { AIFeature.removablePacks(turningOff: selection) }

    var bytesToFree: Int64 { snapshot?.bytes(of: packsToRemove) ?? 0 }

    var isBusy: Bool { step != .idle && step != .finished }

    /// What the toolbar's main button does, given what's installed and what the user has checked.
    nonisolated enum PrimaryAction: Equatable, Sendable {
        /// No DiskDuster profile yet.
        case turnOff
        /// The profile is installed, but the checked features differ from it.
        case applyChanges
        /// The profile matches the checked features, but some of their models are back on disk.
        case removeModels
        /// Everything checked is already off, or nothing is checked: offer to undo it all.
        case restore
    }

    var primaryAction: PrimaryAction {
        Self.primaryAction(installed: snapshot?.profileFeatures, selection: selection, bytesToFree: bytesToFree)
    }

    nonisolated static func primaryAction(
        installed: Set<AIFeature>?, selection: Set<AIFeature>, bytesToFree: Int64
    ) -> PrimaryAction {
        guard let installed else { return .turnOff }
        if selection.isEmpty { return .restore }
        if installed != selection { return .applyChanges }
        return bytesToFree > 0 ? .removeModels : .restore
    }

    /// Lives in the toolbar while the Apple Intelligence screen is showing.
    var actionTitle: String {
        switch primaryAction {
        case .turnOff:
            let count = selection.count
            let base = "Turn Off \(count) AI \(count == 1 ? "Feature" : "Features")"
            return bytesToFree > 0 ? "\(base) and Remove \(ByteFormat.string(bytesToFree))" : base
        case .applyChanges: return "Update AI Settings"
        case .removeModels: return "Remove \(ByteFormat.string(bytesToFree)) of AI Models"
        case .restore: return "Turn AI Features Back On"
        }
    }

    var actionSymbol: String {
        primaryAction == .restore ? "arrow.uturn.backward" : "apple.intelligence"
    }

    var actionHelp: String {
        switch primaryAction {
        case .turnOff: "Turn off the selected features and remove their models"
        case .applyChanges: "Install an updated profile for the features you've checked"
        case .removeModels: "Remove models that downloaded again"
        case .restore: "Remove DiskDuster's profile so Apple Intelligence works again"
        }
    }

    var canPerformPrimaryAction: Bool {
        guard !isBusy, snapshot?.isSupported == true else { return false }
        return primaryAction == .restore || !selection.isEmpty
    }

    func performPrimaryAction() {
        if primaryAction == .restore { restore() } else { turnOff() }
    }

    func refresh() {
        guard isPlatformSupported, !isRefreshing else { return }
        isRefreshing = true
        Task {
            let fresh = await AISnapshot.capture()
            if !hasLoaded, let installed = fresh.profileFeatures {
                selection = installed
            }
            hasLoaded = true
            snapshot = fresh
            isRefreshing = false
        }
    }

    // MARK: - Turning features off

    func turnOff() {
        let features = selection
        guard !features.isEmpty, !isBusy else { return }
        report = nil
        isShowingFlow = true
        flow = Task {
            if AIProfile.installedFeatures() != features {
                do {
                    try presentProfile(disabling: features)
                } catch {
                    let reason = "The profile couldn't be created. \(error.localizedDescription)"
                    finish(AIRunReport(outcome: .failed(reason)))
                    return
                }
                step = .waitingForInstall
                let installed = await poll { AIProfile.installedFeatures() == features }
                guard !Task.isCancelled else { return }
                guard installed else {
                    finish(AIRunReport(outcome: .profileNotInstalled))
                    return
                }
                try? FileManager.default.removeItem(at: AIProfile.fileURL())
            }
            // Models are only removed once the profile is blocking their downloads.
            step = .removingModels("Preparing…")
            let result = await AIModelRemover.remove(AIFeature.removablePacks(turningOff: features)) { message in
                self.step = .removingModels(message)
            }
            finish(result)
        }
    }

    /// Saves the profile and hands it to macOS, which lists it in System Settings for the user to approve.
    /// System Settings stays in the background so the instructions in DiskDuster can be read first; the
    /// user brings it forward with the Open System Settings button.
    private func presentProfile(disabling features: Set<AIFeature>) throws {
        let url = try AIProfile.fileURL()
        try AIProfile.makeData(disabling: features).write(to: url, options: .atomic)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration)
    }

    // MARK: - Turning everything back on

    func restore() {
        guard !isBusy else { return }
        report = nil
        isShowingFlow = true
        step = .waitingForRemoval
        flow = Task {
            let removed = await poll { AIProfile.installedFeatures() == nil }
            guard !Task.isCancelled else { return }
            finish(AIRunReport(outcome: removed ? .restored : .profileStillInstalled))
        }
    }

    // MARK: - Shared

    func cancelFlow() {
        flow?.cancel()
        flow = nil
        step = .idle
        isShowingFlow = false
        refresh()
    }

    func dismissReport() {
        step = .idle
        isShowingFlow = false
        report = nil
    }

    func openProfileSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Profiles-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.configurationprofiles"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }

    private func finish(_ result: AIRunReport) {
        report = result
        step = .finished
        Task {
            snapshot = await AISnapshot.capture()
        }
    }

    /// Checks a condition once a second for up to ten minutes, giving the user time in System Settings.
    private func poll(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<600 {
            if condition() { return true }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return false
            }
        }
        return condition()
    }
}
