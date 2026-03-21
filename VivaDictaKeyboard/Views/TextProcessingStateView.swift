//
//  TextProcessingStateView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.03.21
//

import SwiftUI

/// Shows progress during text processing (rewrite) in the keyboard.
///
/// Displays the current phase with animated icon and status text,
/// plus a cancel button to abort the operation.
struct TextProcessingStateView: View {
    let phase: KeyboardDictationState.TextProcessingPhase
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Cancel button
            HStack {
                Spacer()

                Button {
                    HapticManager.lightImpact()
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(.gray.opacity(0.1), in: .circle)
                        .contentShape(.rect)
                }
                .padding(.horizontal, 8)
            }
            .padding(.bottom, 16)

            // Status content
            VStack(spacing: 16) {
                Image(systemName: statusIcon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeat(.continuous), isActive: isAnimating)

                Text(statusText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 40)
    }

    private var isAnimating: Bool {
        switch phase {
        case .readingText, .sendingToApp, .waitingForResult, .replacing:
            true
        default:
            false
        }
    }

    private var statusIcon: String {
        switch phase {
        case .readingText:
            "text.cursor"
        case .sendingToApp, .waitingForResult:
            "sparkles"
        case .replacing:
            "text.insert"
        case .completed:
            "checkmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        default:
            "sparkles"
        }
    }

    private var statusText: String {
        switch phase {
        case .readingText:
            "Reading text..."
        case .sendingToApp:
            "Sending to app..."
        case .waitingForResult(let presetName):
            "Processing: \(presetName)..."
        case .replacing:
            "Replacing text..."
        case .completed:
            "Done"
        case .error(let message):
            message
        default:
            ""
        }
    }
}
