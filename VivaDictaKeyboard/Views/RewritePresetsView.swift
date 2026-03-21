//
//  RewriteModesView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import SwiftUI

/// Displays available VivaModes in the keyboard for text processing.
///
/// Shows a scrollable list of modes. Tapping a mode triggers the text processing
/// pipeline that reads text from the host app, sends it to the main app for AI
/// processing using that mode, and replaces it with the result.
struct RewriteModesView: View {
    @Environment(KeyboardDictationState.self) var dictationState

    let onModeSelected: (VivaMode) -> Void

    private var modes: [VivaMode] {
        dictationState.vivaModeManager.availableVivaModes
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with V/T segment
            HStack {
                KeyboardTabSegment(dictationState: dictationState)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
                ForEach(modes) { mode in
                    Button {
                        HapticManager.mediumImpact()
                        onModeSelected(mode)
                    } label: {
                        HStack(spacing: 12) {
                            Text(mode.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
            .scrollIndicators(.hidden)
        }
    }
}
