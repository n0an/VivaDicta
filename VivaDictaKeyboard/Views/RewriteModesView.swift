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
///
/// When the main app session is not active, shows a prompt to open the main app.
struct RewriteModesView: View {
    @Environment(KeyboardDictationState.self) var dictationState
    @Environment(\.colorScheme) private var colorScheme

    let onModeSelected: (VivaMode) -> Void
    let onOpenApp: () -> Void
    let onBackspace: () -> Void
    let onNewline: () -> Void
    let onSpace: () -> Void

    private var modes: [VivaMode] {
        dictationState.vivaModeManager.availableVivaModes
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: switcher on left, utility buttons on right
            HStack {
                KeyboardTabToggle(dictationState: dictationState)

                Spacer()

                // Utility buttons: space, return, backspace
                HStack(spacing: 4) {
                    
                    utilityButton(icon: "space", color: .blue, action: onSpace)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                    utilityButton(icon: "return", color: .blue, action: onNewline)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                    utilityButton(icon: "delete.backward", color: .red, action: onBackspace)
                        .shadow(color: .black.opacity(0.2), radius: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            // Content: modes list or "open app" prompt
            if dictationState.isSessionActive {
                modesListView
                    .padding(.horizontal, 24)
            } else {
                openAppPromptView
            }
        }
    }

    // MARK: - Modes List

    private var modesListView: some View {
        VStack {
            Text("Select Mode")
                .font(.system(size: 18, weight: .semibold))
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(modes) { mode in
                        Button {
                            HapticManager.mediumImpact()
                            onModeSelected(mode)
                        } label: {
                            Text(mode.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(colorScheme == .dark ? Color(.quaternarySystemFill).opacity(0.5) : Color.white, in: .rect(cornerRadius: 10))

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

    // MARK: - Open App Prompt

    private var openAppPromptView: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Open VivaDicta")
                .font(.system(size: 18, weight: .semibold))

            Text("Launch the app to use AI text processing")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                HapticManager.mediumImpact()
                onOpenApp()
            } label: {
                Label("Open VivaDicta", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .prominentButton(color: .orange)
            .padding(.vertical, 4)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Utility Button

    
    enum UtilityButtonPlacement {
        case first
        case mid
        case last
    }

    @ViewBuilder
    private func utilityButton(
        icon: String,
        color: Color,
        placement: UtilityButtonPlacement = .mid,
        action: @escaping () -> Void) -> some View {
            
//            let isBackspace = icon == "delete.backward"
//            let tintColor: Color = isBackspace ? .red : .blue
            if #available(iOS 26.0, *) {
                RepeatableButton(action: action) {
                    utilityButtonLabel(icon: icon)
                        .frame(width: 36, height: 20)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .glassEffect(.regular.tint(color.opacity(0.3)).interactive())
                .padding(.trailing, placement == .first ? 4 : 0)
                .padding(.trailing, placement == .last ? 0 : 4)
            } else {
                RepeatableButton(action: action) {
                    utilityButtonLabel(icon: icon)
                        .frame(width: 40, height: 24)
                        .background(color.opacity(0.5), in: .capsule(style: .continuous))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
        }

    private func utilityButtonLabel(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.primary)
            .contentShape(.rect)
    }
}
