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
            }
            .padding(28)
            .frame(maxWidth: 1040)
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
                    .font(.callout)
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
            BasicButton("Turn Everything Back On…", prominence: .secondary, size: .regular) {
                controller.restore()
            }
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
                BasicButton("All", prominence: .secondary, size: .small) {
                    controller.selection = Set(AIFeature.allCases)
                }
                BasicButton("None", prominence: .secondary, size: .small) { controller.selection = [] }
            }
            // Two cards side by side when there's room; one long card when the window is narrow.
            let features = AIFeature.allCases
            let split = (features.count + 1) / 2
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    featureCard(Array(features[..<split]), snapshot)
                    featureCard(Array(features[split...]), snapshot)
                }
                featureCard(features, snapshot)
            }
        }
    }

    private func featureCard(_ features: [AIFeature], _ snapshot: AISnapshot) -> some View {
        VStack(spacing: 0) {
            ForEach(features) { feature in
                featureRow(feature, state: snapshot.states[feature] ?? .unknown)
                if feature != features.last { Divider().padding(.leading, 44) }
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 400)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private func featureRow(_ feature: AIFeature, state: AIFeatureState) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { controller.selection.contains(feature) },
                set: { isOn in
                    if isOn { controller.selection.insert(feature) } else { controller.selection.remove(feature) }
                }
            )) { EmptyView() }
                .toggleStyle(.roundedCheckbox)
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
                    HStack(spacing: 6) {
                        let status = packStatus(pack, bytes: snapshot.packBytes[pack], removing: removing)
                        Text(pack.title)
                        Text("– \(status.text)")
                            .foregroundStyle(status.highlighted ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
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

    private func packStatus(_ pack: AIModelPack, bytes: Int64?, removing: Set<AIModelPack>)
        -> (text: String, highlighted: Bool) {
        if bytes == 0 { return ("nothing to remove", false) }
        return removing.contains(pack) ? ("will be removed", true) : (keptReason(pack), false)
    }

    private func keptReason(_ pack: AIModelPack) -> String {
        let needed = pack.dependents.filter { !controller.selection.contains($0) }.map(\.title)
        return needed.isEmpty ? "kept" : "kept for " + needed.formatted(.list(type: .and))
    }

    private func sizeText(_ bytes: Int64?) -> String {
        guard let bytes else { return "Unknown" }
        return bytes > 0 ? ByteFormat.string(bytes) : "Not installed"
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("macOS asks you to approve a profile in System Settings with your password or biometrics.",
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
}

private struct StateBadge: View {
    let state: AIFeatureState

    var body: some View {
        Text(state.label)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: .capsule)
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch state {
        case .offByDiskDuster: .green
        case .enabled: .orange
        case .off, .offByOtherProfile, .available, .unknown: .secondary
        }
    }
}
