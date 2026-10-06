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
                BasicButton("Cancel", keyboardShortcut: .cancelAction, action: onCancel)
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
                HStack(spacing: 10) {
                    BasicButton("Open Privacy Settings", size: .regular) { model.openFullDiskAccessSettings() }
                    BasicButton("Check Again", prominence: .secondary, size: .regular) { model.refreshSystemState() }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

/// A scope picker in the style of Apple Music's search scopes: one Liquid Glass capsule holding plain-text
/// options, with a softer capsule that slides behind the chosen one.
struct GlassSegmentedControl<Value: Hashable & Sendable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var id: Value { value }
    }

    @Binding var selection: Value
    let options: [Option]
    @Namespace private var highlightNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option.value == selection
        return Button {
            withAnimation(.smooth(duration: 0.25)) { selection = option.value }
        } label: {
            Text(option.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.primary.opacity(0.12))
                            .matchedGeometryEffect(id: "highlight", in: highlightNamespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
