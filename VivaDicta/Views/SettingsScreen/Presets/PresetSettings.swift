//
//  PresetSettings.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.02.20
//

import SwiftUI

struct PresetSettings: View {
    var presetManager: PresetManager

    var body: some View {
        List {
            ForEach(presetManager.categories, id: \.self) { category in
                Section(category) {
                    ForEach(presetManager.presets(in: category)) { preset in
                        NavigationLink(value: preset) {
                            PresetRowView(preset: preset)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !preset.isBuiltIn {
                                Button("Delete", role: .destructive) {
                                    deletePreset(preset)
                                }
                            }
                        }
                    }
                }
            }
        }
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationTitle("Presets")
    }

    private func deletePreset(_ preset: Preset) {
        HapticManager.mediumImpact()
        presetManager.deletePreset(preset)
    }
}

private struct PresetRowView: View {
    let preset: Preset

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: preset.icon)
                .font(.system(size: 14))
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.headline)

                if preset.isEdited {
                    Text("Edited")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}
