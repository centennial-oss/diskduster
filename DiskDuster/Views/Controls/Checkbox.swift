//
//  Checkbox.swift
//  DiskDuster
//

import SwiftUI

/// The rounded checkbox used throughout Centennial OSS apps: a filled checkmark circle when on, an empty ring
/// when off, and a filled minus circle when only some of the things it controls are on.
struct Checkbox<Label: View>: View {
    enum State {
        case unchecked, checked, mixed
    }

    let state: State
    @ViewBuilder let label: () -> Label
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .imageScale(.medium)
                // Monochrome: the circle carries the color and the check or dash is cut out of it.
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
            label()
        }
        .opacity(isEnabled ? 1 : 0.4)
    }

    /// In DiskDuster a check means "this will be cleaned", so checked is red and partly checked is orange.
    private var tint: Color {
        switch state {
        case .unchecked: .secondary
        case .checked: .red
        case .mixed: .orange
        }
    }

    private var symbol: String {
        switch state {
        case .unchecked: "circle"
        case .checked: "checkmark.circle.fill"
        case .mixed: "minus.circle.fill"
        }
    }
}

/// Draws any `Toggle` as a rounded `Checkbox`, including `Toggle(sources:isOn:)` in its mixed state.
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let state: Checkbox<Configuration.Label>.State =
            configuration.isMixed ? .mixed : (configuration.isOn ? .checked : .unchecked)
        Button {
            // A mixed checkbox turns everything on, matching the system checkbox.
            configuration.isOn = configuration.isMixed ? true : !configuration.isOn
        } label: {
            Checkbox(state: state) {
                configuration.label
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(state == .mixed ? "Mixed" : (state == .checked ? "On" : "Off")))
    }
}

extension ToggleStyle where Self == CheckboxToggleStyle {
    /// The rounded Centennial OSS checkbox. Use this instead of `.checkbox` everywhere in DiskDuster.
    static var roundedCheckbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
