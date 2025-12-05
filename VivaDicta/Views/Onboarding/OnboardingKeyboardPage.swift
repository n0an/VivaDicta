//
//  OnboardingKeyboardPage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

struct OnboardingKeyboardPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Keyboard Illustration
                KeyboardIllustration()
                    .padding(.top, 16)

                // Title
                VStack(spacing: 4) {
                    Text("Record Anywhere ")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                    +
                    Text("You Type")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.blue)
                }

                // Subtitle
                Text("Use VivaDicta keyboard to transcribe in any app")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Feature Cards
                VStack(spacing: 12) {
                    OnboardingFeatureCard(
                        icon: "record.circle",
                        iconColor: .red,
                        backgroundColor: Color(.systemGray6),
                        text: "Quick voice input in any text field"
                    )

                    OnboardingFeatureCard(
                        icon: "keyboard",
                        iconColor: .blue,
                        backgroundColor: Color(.systemGray6),
                        text: "Full keyboard with recording button"
                    )
                }
                .padding(.horizontal, 24)

                // Setup Instructions
                OnboardingCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Setup Instructions")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            OnboardingInstructionRow(number: 1, text: "Tap 'Open Settings' below")
                            OnboardingInstructionRow(number: 2, text: "Go to Keyboards → Keyboards")
                            OnboardingInstructionRow(number: 3, text: "Add VivaDicta Keyboard")
                            OnboardingInstructionRow(number: 4, text: "Enable 'Allow Full Access'")
                        }

                        OnboardingInfoBox(
                            icon: "info.circle.fill",
                            text: "Full Access is required for voice recording. We never collect your keystrokes or personal data.",
                            backgroundColor: Color.yellow.opacity(0.15),
                            textColor: .orange
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Keyboard Illustration

private struct KeyboardIllustration: View {
    var body: some View {
        VStack(spacing: 8) {
            // Row 1
            HStack(spacing: 6) {
                ForEach(["Q", "W", "E", "R", "T", "Y"], id: \.self) { key in
                    KeyCap(letter: key)
                }
            }

            // Row 2
            HStack(spacing: 6) {
                ForEach(["A", "S", "D", "F", "G", "H"], id: \.self) { key in
                    KeyCap(letter: key)
                }
            }

            // Row 3 with mic button
            HStack(spacing: 6) {
                KeyCap(letter: "space", isWide: true)

                // Mic button
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct KeyCap: View {
    let letter: String
    var isWide: Bool = false

    var body: some View {
        Text(letter)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: isWide ? 80 : 32, height: 36)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
}

#Preview {
    OnboardingKeyboardPage()
        .background(Color(.systemGroupedBackground))
}
