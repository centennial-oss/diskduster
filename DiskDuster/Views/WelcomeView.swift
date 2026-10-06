//
//  WelcomeView.swift
//  DiskDuster
//

import SwiftUI

struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.tint)
                    Text("DiskDuster")
                        .font(.largeTitle.weight(.bold))
                    Text("Dust off your Mac and reclaim space.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text("""
                    DiskDuster finds caches, logs, developer leftovers and other files that are safe to remove, \
                    shows how much space each one uses, and cleans only what you choose.
                    """)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)

                VStack(spacing: 12) {
                    BasicButton(
                        "Scan My Mac", systemImage: "magnifyingglass", size: .extraLarge,
                        keyboardShortcut: .defaultAction
                    ) {
                        model.startScan()
                    }

                    Toggle("Include system locations", isOn: $settings.includeSystemLocations)
                        .toggleStyle(.roundedCheckbox)
                    Text("Cleaning system items asks for an administrator password. "
                        + "Leave this off to stay in your home folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    promise("gift", "100% free, forever, with no ads.")
                    promise("hand.raised", "100% private. No analytics, no tracking, no network access.")
                    promise("chevron.left.forwardslash.chevron.right", "100% open source.")
                }

                if !model.hasFullDiskAccess {
                    FullDiskAccessCard()
                        .frame(maxWidth: 560)
                }
            }
            .padding(48)
            .frame(maxWidth: .infinity)
        }
    }

    private func promise(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 22)
        }
    }
}
