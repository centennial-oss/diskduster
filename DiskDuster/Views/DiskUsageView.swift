//
//  DiskUsageView.swift
//  DiskDuster
//

import SwiftUI

/// The startup disk at a glance: a bar split into what's in use, what's selected for cleaning, and what macOS
/// is holding for itself, with a legend underneath. The header shows "available" (free space plus what macOS
/// frees on demand), which is what Finder and Get Info show.
struct DiskUsageView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let volume = model.volume {
            let breakdown = CapacityBreakdown(
                volume: volume,
                fullySelected: selectedBytes(where: .all),
                partlySelected: selectedBytes(where: .some)
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(volume.name, systemImage: "internaldrive")
                        .font(.callout.weight(.medium))
                    Spacer()
                    Text("\(ByteFormat.string(breakdown.available)) available")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .help("\(ByteFormat.string(breakdown.free)) is free right now. macOS frees the other "
                            + "\(ByteFormat.string(breakdown.reserved)) automatically when apps need it.")
                }
                CapacityBar(segments: [
                    .init(color: .accentColor, fraction: breakdown.fraction(breakdown.inUse)),
                    .init(color: .red, fraction: breakdown.fraction(breakdown.fullySelected)),
                    .init(color: .orange, fraction: breakdown.fraction(breakdown.partlySelected)),
                    .init(color: .purple, fraction: breakdown.fraction(breakdown.reserved))
                ])
                legend(breakdown)
            }
        }
    }

    private func legend(_ breakdown: CapacityBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LegendRow(symbol: "circle.fill", color: .accentColor,
                      text: "\(ByteFormat.string(breakdown.inUse)) in use")
            if breakdown.fullySelected > 0 {
                LegendRow(symbol: "trash.fill", color: .red,
                          text: "\(ByteFormat.string(breakdown.fullySelected)) in fully selected categories")
            }
            if breakdown.partlySelected > 0 {
                LegendRow(symbol: "trash.fill", color: .orange,
                          text: "\(ByteFormat.string(breakdown.partlySelected)) in partly selected categories")
            }
            if breakdown.reserved > 0 {
                LegendRow(symbol: "lock.fill", color: .purple,
                          text: "macOS is reserving \(ByteFormat.string(breakdown.reserved)) for system use")
                    .help("Purgeable space such as local Time Machine snapshots, iCloud copies and system caches. "
                        + "macOS frees it automatically when space is needed.")
            }
        }
    }

    /// Bytes selected for cleaning in categories that are fully (`.all`) or partly (`.some`) checked.
    private func selectedBytes(where state: SelectionState) -> Int64 {
        model.visibleCategories
            .filter { model.selectionState(of: $0) == state }
            .reduce(0) { $0 + model.selectedBytes(in: $1) }
    }
}

private struct LegendRow: View {
    let symbol: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(2)
        }
    }
}

/// A capsule track filled left to right with colored segments; whatever is left over is free space.
struct CapacityBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let color: Color
        let fraction: Double
    }

    let segments: [Segment]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: max(0, geometry.size.width * segment.fraction))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 8)
        .background(Capsule().fill(.quaternary))
        .clipShape(.capsule)
        .accessibilityHidden(true)
    }
}
