//
//  OnboardingWelcomePage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

struct OnboardingWelcomePage: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App Icon
            OnboardingAppIcon(gradient: [.blue, .blue.opacity(0.7)], size: 120)
                .padding(.bottom, 40)

            // Title
            VStack(spacing: 4) {
                Text("Welcome to")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text("VivaDicta")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.blue)
            }
            .padding(.bottom, 16)

            // Subtitle
            Text("Transform your voice into perfect text with AI-powered transcription")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

            // Features
            VStack(spacing: 20) {
                OnboardingFeatureRow(
                    icon: "shield.checkmark.fill",
                    iconColor: .green,
                    text: "Complete privacy - your data stays on device"
                )

                OnboardingFeatureRow(
                    icon: "cpu.fill",
                    iconColor: .blue,
                    text: "Advanced AI models for perfect accuracy"
                )

                OnboardingFeatureRow(
                    icon: "wand.and.stars",
                    iconColor: .purple,
                    text: "AI enhancement for professional results"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

        }
    }
}

#Preview {
    OnboardingWelcomePage(onContinue: {})
        .background(Color(.systemGroupedBackground))
}
