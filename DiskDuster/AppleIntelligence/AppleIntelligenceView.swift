//
//  AppleIntelligenceView.swift
//  DiskDuster
//

import SwiftUI

struct AppleIntelligenceView: View {
    @Environment(AppleIntelligenceController.self) private var controller

    var body: some View {
        @Bindable var controller = controller
        Group {
            if let snapshot = controller.snapshot {
                if snapshot.isSupported {
                    content(snapshot)
                } else {
                    ContentUnavailableView(
                        "Apple Intelligence Isn't Available",
                        systemImage: "apple.intelligence",
                        description: Text("This Mac doesn't have Apple Intelligence models to manage.")
                    )
                }
            } else {
                ProgressView("Checking Apple Intelligence…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Apple Intelligence")
        .onAppear { controller.refresh() }
        .sheet(isPresented: $controller.isShowingFlow) {
            AIFlowSheet()
                .interactiveDismissDisabled()
        }
    }

    private func content(_ snapshot: AISnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(snapshot)
                if let installed = snapshot.profileFeatures {
                    profileBanner(count: installed.count)
                }
                featureSection(snapshot)
                modelSection(snapshot)
                notes
                actionBar
            }
            .padding(28)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
    }

    private func header(_ snapshot: AISnapshot) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Intelligence")
                    .font(.largeTitle.weight(.bold))
                Text("Turn off the features you don't use and remove the models they downloaded. You can turn "
                    + "everything back on at any time.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(snapshot.totalModelBytes.map { ByteFormat.string($0) } ?? "Unknown")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("models on disk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func profileBanner(count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.title2)
                .foregroundStyle(.green)
            Text("DiskDuster is keeping \(count) \(count == 1 ? "feature" : "features") turned off.")
            Spacer()
            Button("Turn Everything Back On…") { controller.restore() }
                .disabled(controller.isBusy)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private func featureSection(_ snapshot: AISnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Features to Turn Off").font(.title3.weight(.semibold))
                Spacer()
                Button("All") { controller.selection = Set(AIFeature.allCases) }
                Button("None") { controller.selection = [] }
            }
            .buttonStyle(.borderless)
            VStack(spacing: 0) {
                ForEach(AIFeature.allCases) { feature in
                    featureRow(feature, state: snapshot.states[feature] ?? .unknown)
                    if feature != AIFeature.allCases.last { Divider().padding(.leading, 44) }
                }
            }
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
    }

    private func featureRow(_ feature: AIFeature, state: AIFeatureState) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { controller.selection.contains(feature) },
                set: { isOn in
                    if isOn { controller.selection.insert(feature) } else { controller.selection.remove(feature) }
                }
            )) { EmptyView() }
                .toggleStyle(.checkbox)
                .labelsHidden()
            Image(systemName: feature.symbol)
                .foregroundStyle(.tint)
                .frame(width: 20)
            Text(feature.title)
            Spacer()
            StateBadge(state: state)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func modelSection(_ snapshot: AISnapshot) -> some View {
        let removing = Set(controller.packsToRemove)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Downloaded Models").font(.title3.weight(.semibold))
            VStack(spacing: 0) {
                ForEach(AIModelPack.allCases) { pack in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.title)
                            Text(removing.contains(pack) ? "Will be removed" : keptReason(pack))
                                .font(.caption)
                                .foregroundStyle(removing.contains(pack) ? AnyShapeStyle(.orange)
                                                                         : AnyShapeStyle(.secondary))
                        }
                        Spacer()
                        Text(sizeText(snapshot.packBytes[pack]))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    if pack != AIModelPack.allCases.last { Divider().padding(.leading, 14) }
                }
            }
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
    }

    private func keptReason(_ pack: AIModelPack) -> String {
        let needed = pack.dependents.filter { !controller.selection.contains($0) }.map(\.title)
        return needed.isEmpty ? "Kept" : "Kept for " + needed.formatted(.list(type: .and))
    }

    private func sizeText(_ bytes: Int64?) -> String {
        guard let bytes else { return "Unknown" }
        return bytes > 0 ? ByteFormat.string(bytes) : "Not installed"
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("macOS asks you to approve a profile in System Settings. This needs your password.",
                  systemImage: "lock.shield")
            Label("The profile keeps removed models from downloading again. Remove it to undo everything.",
                  systemImage: "arrow.uturn.backward")
            Label("Dictation and other speech features aren't affected.", systemImage: "mic")
            Label("macOS deletes model files on its own schedule, so Storage settings may take a while to catch up.",
                  systemImage: "clock")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private var actionBar: some View {
        HStack {
            Spacer()
            Button {
                controller.turnOff()
            } label: {
                Text(actionTitle).padding(.horizontal, 10)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(controller.selection.isEmpty || controller.isBusy)
        }
    }

    private var actionTitle: String {
        let count = controller.selection.count
        let base = "Turn Off \(count) \(count == 1 ? "Feature" : "Features")"
        return controller.bytesToFree > 0 ? "\(base) and Remove \(ByteFormat.string(controller.bytesToFree))" : base
    }
}

private struct StateBadge: View {
    let state: AIFeatureState

    var body: some View {
        Text(state.label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: .capsule)
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch state {
        case .offByDiskDuster: .green
        case .on: .orange
        case .off, .offByOtherProfile, .available, .unknown: .secondary
        }
    }
}
