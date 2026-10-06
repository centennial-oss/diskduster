//
//  LabeledSwitch.swift
//  DiskDuster
//

import SwiftUI

/// A single on/off option: the label on the left and an accent-tinted switch on the right, as in MIDI Scribe's
/// sidebar. Use this for a standalone option; use the rounded checkbox for lists of selectable items.
struct LabeledSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.accentColor)
        }
    }
}
