//
//  OnboardingKeyboardPage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

struct OnboardingKeyboardPage: View {
    @State private var t: Float = 0.0
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Dictate")
                        .foregroundStyle(meshGradient)
                    Text("Anywhere You Type")
                }

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
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                Task { @MainActor in
                    t += 0.02
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var meshGradient: MeshGradient {
        MeshGradient(width: 3, height: 3, points: [
            .init(0, 0), .init(0.5, 0), .init(1, 0),
            [sinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), sinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), sinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), sinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
            [sinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), sinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), sinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), sinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
        ], colors: [
            .blue, .purple, .indigo,
            .cyan, .pink, .blue,
            .purple, .indigo, .cyan
        ])
    }

    private func sinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
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
