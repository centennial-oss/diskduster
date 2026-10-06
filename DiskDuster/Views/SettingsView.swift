//
//  SettingsView.swift
//  DiskDuster
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("When cleaning your files", selection: $settings.deletionMode) {
                    ForEach(DeletionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Cleaning")
            } footer: {
                Text("Items already in the Trash, and system items, are always deleted permanently.")
            }

            Section {
                Toggle("Include system locations", isOn: $settings.includeSystemLocations)
                ForEach(CleanupCategory.allCases) { category in
                    Toggle(isOn: Binding(
                        get: { settings.isEnabled(category) },
                        set: { settings.setEnabled(category, $0) }
                    )) {
                        Label(category.title, systemImage: category.symbol)
                    }
                    .disabled(category.requiresAdmin && !settings.includeSystemLocations)
                }
            } header: {
                Text("What to Scan")
            } footer: {
                Text("System locations need an administrator password to clean. When they're off, DiskDuster "
                    + "stays inside your home folder and never asks for a password.")
            }

            Section("Preserved Apps") {
                if settings.preservedApps.isEmpty {
                    Text("Preserve an app in the Apps list to keep all of its files in every category.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.preservedApps.sorted { $0.value < $1.value }, id: \.key) { key, name in
                        HStack {
                            Text(name)
                            Spacer()
                            BasicButton("Remove", prominence: .secondary, size: .small) {
                                settings.preservedApps[key] = nil
                            }
                        }
                    }
                }
            }

            Section("Ignored Items") {
                if settings.ignoredPaths.isEmpty {
                    Text("Right-click an item and choose Always Ignore to skip it in future scans.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.ignoredPaths, id: \.self) { path in
                        HStack {
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(path)
                            Spacer()
                            BasicButton("Remove", prominence: .secondary, size: .small) {
                                settings.unignore(path)
                            }
                        }
                    }
                }
            }

            Section("Privacy") {
                LabeledContent("Full Disk Access") {
                    HStack {
                        Text(model.hasFullDiskAccess ? "On" : "Off")
                            .foregroundStyle(model.hasFullDiskAccess ? .green : .orange)
                        BasicButton("Open Settings", prominence: .secondary, size: .small) {
                            model.openFullDiskAccessSettings()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 560)
        .onAppear { model.refreshSystemState() }
    }
}
