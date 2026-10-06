//
//  BasicButton.swift
//  DiskDuster
//

import AppKit
import SwiftUI

/// Everything a `BasicButton` needs, so call sites read the same way across Centennial OSS apps.
struct BasicButtonContext {
    enum Prominence {
        /// Filled Liquid Glass in the accent color (red for destructive actions). Use for the main action.
        case primary
        /// Clear Liquid Glass. Use for Cancel and other secondary actions next to a primary one.
        case secondary
    }

    let action: () -> Void
    let label: String
    var systemImage: String?
    var role: ButtonRole?
    var prominence: Prominence
    var keyboardShortcut: KeyboardShortcut?
    var size: ControlSize
    var labelWeight: Font.Weight
    var backgroundColor: Color?
    var foregroundColor: Color?

    init(
        action: @escaping () -> Void,
        label: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        prominence: Prominence = .primary,
        keyboardShortcut: KeyboardShortcut? = nil,
        size: ControlSize = .large,
        labelWeight: Font.Weight = .semibold,
        backgroundColor: Color? = nil,
        foregroundColor: Color? = nil
    ) {
        self.action = action
        self.label = label
        self.systemImage = systemImage
        self.role = role
        self.prominence = prominence
        self.keyboardShortcut = keyboardShortcut
        self.size = size
        self.labelWeight = labelWeight
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
}

/// The rounded Liquid Glass button used for every in-window action in DiskDuster. Use this instead of a plain
/// `Button` so all buttons share the accent color, shape and type size.
struct BasicButton: View {
    let context: BasicButtonContext

    init(context: BasicButtonContext) {
        self.context = context
    }

    init(
        _ label: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        prominence: BasicButtonContext.Prominence = .primary,
        size: ControlSize = .large,
        keyboardShortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) {
        context = BasicButtonContext(
            action: action, label: label, systemImage: systemImage, role: role, prominence: prominence,
            keyboardShortcut: keyboardShortcut, size: size
        )
    }

    var body: some View {
        styled(Button(role: context.role, action: context.action) { labelContent })
            .keyboardShortcut(context.keyboardShortcut)
            .accessibilityLabel(context.label)
    }

    private var tint: Color {
        context.backgroundColor ?? (context.role == .destructive ? .red : .accentColor)
    }

    private var labelColor: Color {
        if let foregroundColor = context.foregroundColor { return foregroundColor }
        switch context.prominence {
        case .primary: return Color(nsColor: .windowBackgroundColor)
        case .secondary: return .primary
        }
    }

    private var labelFont: Font {
        let points: CGFloat = switch context.size {
        case .mini: 11
        case .small: 12
        case .regular: 13
        case .extraLarge: 17
        default: 15
        }
        return .system(size: points, weight: context.labelWeight)
    }

    private var labelContent: some View {
        HStack(spacing: 8) {
            if let systemImage = context.systemImage {
                Image(systemName: systemImage)
            }
            Text(context.label)
        }
        .font(labelFont)
        .padding(.horizontal, context.size == .small || context.size == .mini ? 2 : 6)
        .foregroundStyle(labelColor)
    }

    @ViewBuilder
    private func styled(_ button: some View) -> some View {
        switch context.prominence {
        case .primary:
            button
                .buttonStyle(.glassProminent)
                .tint(tint)
                .controlSize(context.size)
        case .secondary:
            button
                .buttonStyle(.glass)
                .tint(context.backgroundColor)
                .controlSize(context.size)
        }
    }
}
