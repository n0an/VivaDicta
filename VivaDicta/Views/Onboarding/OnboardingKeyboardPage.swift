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
                (Text("Record Anywhere ")
                    .foregroundStyle(.primary)
                +
                Text("You\u{00A0}Type")
                    .foregroundStyle(.blue))
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 36)
                
                KeyboardIllustration()
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 4, y: 6)
//                    .padding(.horizontal, 24)
                

                // Subtitle
                Text("Use VivaDicta keyboard to transcribe in any app")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)


                // Setup Instructions
                OnboardingCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Setup Instructions")
                            .font(.title3.weight(.bold))

                        VStack(alignment: .leading, spacing: 12) {
                            OnboardingInstructionRow(number: 1, text: "Tap **Open Settings** below")
                            OnboardingInstructionRow(number: 2, text: "Go to **Keyboards** section")
                            OnboardingInstructionRow(number: 3, text: "Enable **VivaDicta** Keyboard")
                            OnboardingInstructionRow(number: 4, text: "Enable **Allow Full Access**")
                        }

                        // Settings preview
                        SettingsTogglesPreview()

                        OnboardingInfoBox(
                            icon: "info.circle.fill",
                            text: "Full Access is required for voice recording. We never collect your keystrokes or personal data.",
                            backgroundColor: Color.yellow.opacity(0.15),
                            textColor: .orange
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Settings Toggles Preview

private struct SettingsTogglesPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // VivaDicta toggle row
            SettingsToggleRow(title: "VivaDicta", icon: nil, isOn: true)

            Divider()
                .padding(.leading, 16)

            // Allow Full Access toggle row
            SettingsToggleRow(
                title: "Allow Full Access",
                icon: "keyboard",
                isOn: true
            )
        }
        .background(cellBackground, in: RoundedRectangle(cornerRadius: 10))
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 10, x: 4, y: 6)
    }

    private var cellBackground: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground)
    }
}

private struct SettingsToggleRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let icon: String?
    let isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconForeground)
                    .frame(width: 28, height: 28)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: 6))
            }

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // Fake toggle (not interactive)
            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var iconBackground: Color {
        colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5)
    }

    private var iconForeground: Color {
        colorScheme == .dark ? Color(.systemGray) : Color(.systemGray2)
    }
}

#Preview {
    OnboardingKeyboardPage()
        .background(Color(.systemGroupedBackground))
}
