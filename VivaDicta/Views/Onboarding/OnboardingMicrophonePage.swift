//
//  OnboardingMicrophonePage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI
import AVFoundation

enum MicrophonePermissionState {
    case undetermined
    case granted
    case denied
}

struct OnboardingMicrophonePage: View {
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var permissionState: MicrophonePermissionState = .undetermined

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.primary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Main Card
            OnboardingCard {
                HStack(spacing: 16) {
                    OnboardingAppIcon(gradient: [.pink, .cyan], size: 80)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Microphone Access")
                            .font(.title2.weight(.bold))

                        Text("Required to record your voice for transcription. Your audio is processed locally on your device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Privacy Card
                OnboardingPrivacyCard(
                    title: "Privacy Guaranteed",
                    description: "Audio never leaves your device unless you choose cloud enhancement."
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()

            // Button
            VStack(spacing: 12) {
                switch permissionState {
                case .granted:
                    // Already granted - show continue button
                    OnboardingPrimaryButton(
                        title: "Continue",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        action: onContinue
                    )
                case .denied:
                    // Denied - show open settings
                    OnboardingPrimaryButton(
                        title: "Open Settings",
                        icon: "gear",
                        color: .orange,
                        action: openSettings
                    )

                    Text("Microphone access was denied. Please enable it in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                case .undetermined:
                    // Not determined - show request button
                    OnboardingPrimaryButton(
                        title: "Enable Microphone Access",
                        icon: "mic.fill",
                        color: .green,
                        action: requestPermission
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onAppear {
            checkPermissionStatus()
        }
    }

    private func checkPermissionStatus() {
        let status = AVAudioApplication.shared.recordPermission
        switch status {
        case .granted:
            permissionState = .granted
        case .denied:
            permissionState = .denied
        case .undetermined:
            permissionState = .undetermined
        @unknown default:
            permissionState = .undetermined
        }
    }

    private func requestPermission() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                permissionState = granted ? .granted : .denied
                if granted {
                    // Small delay before continuing
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    onContinue()
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    OnboardingMicrophonePage(onBack: {}, onContinue: {})
        .background(Color(.systemGroupedBackground))
}
