//
//  OnboardingMicrophonePage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

enum MicrophonePermissionState {
    case undetermined
    case granted
    case denied
}

struct OnboardingMicrophonePage: View {
    @Binding var permissionState: MicrophonePermissionState

    var body: some View {
        VStack(spacing: 0) {
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
        }
    }
}

#Preview {
    OnboardingMicrophonePage(permissionState: .constant(.undetermined))
        .background(Color(.systemGroupedBackground))
}
