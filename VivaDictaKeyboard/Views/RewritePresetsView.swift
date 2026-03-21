//
//  RewritePresetsView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import SwiftUI

/// Displays available AI presets in the keyboard for text processing.
///
/// Shows a scrollable list of presets organized by category. Tapping a preset
/// triggers the text processing pipeline that reads text from the host app,
/// sends it to the main app for AI processing, and replaces it with the result.
struct RewritePresetsView: View {
    @Environment(KeyboardDictationState.self) var dictationState

    let onPresetSelected: (Preset) -> Void
    let onDismiss: () -> Void

    @State private var groupedPresets: [(category: String, presets: [Preset])] = []
    private let presetProvider = KeyboardPresetProvider()

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Rewrite")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                // Spacer for symmetry
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Preset list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(groupedPresets, id: \.category) { group in
                        Section {
                            ForEach(group.presets) { preset in
                                Button {
                                    HapticManager.mediumImpact()
                                    onPresetSelected(preset)
                                } label: {
                                    HStack(spacing: 10) {
                                        PresetIconView(icon: preset.icon, fontSize: 18)
                                            .frame(width: 24)

                                        Text(preset.name)
                                            .font(.system(size: 15))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(group.category)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 12)
                                .padding(.top, group.category == groupedPresets.first?.category ? 0 : 4)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            groupedPresets = presetProvider.loadGroupedPresets()
        }
    }
}
