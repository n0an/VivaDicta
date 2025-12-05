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
                VStack(spacing: 4) {
                    Text("Record Anywhere ")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                    +
                    Text("You Type")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.blue)
                }
                .padding(.top, 36)
                
                KeyboardIllustration()
                    .padding(.horizontal, 24)
                

                // Subtitle
                Text("Use VivaDicta keyboard to transcribe in any app")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)


                // Setup Instructions
                OnboardingCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Setup Instructions")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            OnboardingInstructionRow(number: 1, text: "Tap **Open Settings** below")
                            OnboardingInstructionRow(number: 2, text: "Go to **Keyboards** section")
                            OnboardingInstructionRow(number: 3, text: "Enable **VivaDicta** Keyboard")
                            OnboardingInstructionRow(number: 4, text: "Enable **Allow Full Access**")
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

#Preview {
    OnboardingKeyboardPage()
        .background(Color(.systemGroupedBackground))
}
