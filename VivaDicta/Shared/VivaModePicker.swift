//
//  VivaModePicker.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.13
//

import SwiftUI

struct VivaModePicker: View {
    let modes: [VivaMode]
    @Binding var selectedModeName: String
    var onSelectionChanged: (() -> Void)?

    var body: some View {
        Menu {
            ForEach(modes) { mode in
                Button {
                    selectedModeName = mode.name
                    onSelectionChanged?()
                } label: {
                    if mode.name == selectedModeName {
                        Label(mode.name, systemImage: "checkmark")
                    } else {
                        Text(mode.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedModeName)
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                    .frame(maxWidth: 150)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.tertiary, in: .capsule)
        }
        .tint(.primary)
        .accessibilityLabel("Mode selector")
        .accessibilityValue(selectedModeName)
        .accessibilityHint("Double tap to choose a different mode")
    }
}

#Preview {
    VivaModePicker(
        modes: [VivaMode.defaultMode],
        selectedModeName: .constant("Default")
    )
}
