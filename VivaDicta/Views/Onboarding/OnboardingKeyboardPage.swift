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
                
                

//                // Title
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
                
//                Image("keyboard")
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 200)

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

// MARK: - Keyboard Illustration

private struct KeyboardIllustration: View {
    private let keySpacing: CGFloat = 6
    private let keyHeight: CGFloat = 42
    private let keyWidth: CGFloat = 33

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with MicButton
            HStack {
                Spacer()

                MicButton(
                    fontSize: 34,
                    padding: 6,
                    backgroundColor: .orange.opacity(0.5),
                    borderWidth: 0.5,
                    onTapAction: {}
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Row 1: QWERTYUIOP
            HStack(spacing: keySpacing) {
                ForEach(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], id: \.self) { key in
                    KeyCap(letter: key, width: keyWidth, height: keyHeight)
                }
            }
            .padding(.bottom, keySpacing)

            // Row 2: ASDFGHJKL
            HStack(spacing: keySpacing) {
                ForEach(["A", "S", "D", "F", "G", "H", "J", "K", "L"], id: \.self) { key in
                    KeyCap(letter: key, width: keyWidth, height: keyHeight)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 4)
        .background(Color(.systemGray4).opacity(0.5))
    }
}

private struct KeyCap: View {
    let letter: String
    var width: CGFloat = 32
    var height: CGFloat = 44

    var body: some View {
        Text(letter)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.primary)
            .frame(width: width, height: height)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.15), radius: 0.5, y: 1)
    }
}

#Preview {
    OnboardingKeyboardPage()
        .background(Color(.systemGroupedBackground))
    
    
//    KeyboardIllustration()
}
