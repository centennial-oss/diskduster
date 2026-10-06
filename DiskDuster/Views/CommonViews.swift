//
//  CommonViews.swift
//  DiskDuster
//

import SwiftUI

/// A checkbox that shows a mixed state when only some of a category's items are selected.
struct CategoryCheckbox: View {
    @Environment(AppModel.self) private var model
    let category: CleanupCategory

    var body: some View {
        let sources = model.selectableItems(in: category).map { item in
            Binding(get: { model.isSelected(item) }, set: { model.setSelected($0, item: item) })
        }
        Group {
            if sources.isEmpty {
                // Toggle(sources:) reports an empty collection as checked, so show a plain empty box instead.
                Toggle(isOn: .constant(false)) { EmptyView() }
                    .disabled(true)
            } else {
                Toggle(sources: sources, isOn: \.self) { EmptyView() }
            }
        }
        .toggleStyle(.roundedCheckbox)
        .help("Select or deselect everything in \(category.title)")
    }
}

/// A full-screen progress display used while scanning or cleaning.
struct ProgressPanel: View {
    let title: String
    let message: String
    var fraction: Double?
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 22) {
            if let fraction {
                ProgressView(value: fraction)
                    .frame(width: 440)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 600)
            if let onCancel {
                Button(action: onCancel) {
                    Text("Cancel")
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .padding(.top, 6)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Explains why Full Disk Access matters and links to System Settings.
struct FullDiskAccessCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.title)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Full Disk Access recommended")
                    .font(.headline)
                Text("""
                    Without it, macOS hides app containers and the Trash from DiskDuster. You can still scan, \
                    but less will be found. In System Settings, turn on DiskDuster (or click + to add it), \
                    then quit and reopen DiskDuster.
                    """)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Open Privacy Settings") { model.openFullDiskAccessSettings() }
                    Button("Check Again") { model.refreshSystemState() }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

/// Free-space gauge for the startup volume.
struct DiskUsageView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let volume = model.volume {
            VStack(alignment: .leading, spacing: 6) {
                Label(volume.name, systemImage: "internaldrive")
                    .font(.callout.weight(.medium))
                ProgressView(value: volume.usedFraction)
                    .tint(volume.usedFraction > 0.9 ? .red : .accentColor)
                Text("\(ByteFormat.string(volume.availableBytes)) available of \(ByteFormat.string(volume.totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

/// A segmented control drawn with Liquid Glass: each option is a glass capsule, and the chosen one is tinted.
struct GlassSegmentedControl<Value: Hashable & Sendable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var id: Value { value }
    }

    @Binding var selection: Value
    let options: [Option]
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(options) { option in
                    if option.value == selection {
                        segment(option).buttonStyle(.glassProminent)
                    } else {
                        segment(option).buttonStyle(.glass)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(_ option: Option) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { selection = option.value }
        } label: {
            Text(option.title)
                .padding(.horizontal, 4)
        }
        .glassEffectID(option.id, in: glassNamespace)
        .accessibilityAddTraits(option.value == selection ? .isSelected : [])
    }
}
