//
//  KeyboardReturnPromptView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.05
//

import SwiftUI
import DesignSystem

/// Full-screen prompt shown when the keyboard dictation flow can't
/// automatically return the user to the host app (e.g. the host has no
/// URL scheme, or iOS didn't supply the host bundle id). It tells the
/// user to swipe back so dictation continues in the keyboard.
///
/// Dismisses when the user swipes back (the app resigns active - see
/// `VivaDictaApp` scene-phase handling), taps Dismiss, or after a timeout.
struct KeyboardReturnPromptView: View {
    @Environment(AppState.self) private var appState

    /// Auto-dismiss after this many seconds if the user doesn't swipe back.
    private static let autoDismissSeconds = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusPill

            Text("Swipe back to continue")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(Color.vivaAccent)

            Spacer()

            Image("VivaDictaIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Spacer()

            VStack(spacing: 16) {
                Text("We wish you didn't have to switch apps to use VivaDicta, but Apple requires this step to activate the microphone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Button("Dismiss", action: dismiss)
                    .font(.headline)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            HapticManager.mediumImpact()
            do {
                try await Task.sleep(for: .seconds(Self.autoDismissSeconds))
                dismiss()
            } catch {
                // Cancelled because the view is going away (swipe-back, Dismiss,
                // or scene-phase reset) - nothing to do.
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
            Text("Keyboard active")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffectOrMaterial()
        .clipShape(.capsule)
    }

    private func dismiss() {
        // fullScreenCover uses the system modal-dismissal transition, so an
        // explicit withAnimation here would have no effect.
        appState.showKeyboardReturnPrompt = false
    }
}
