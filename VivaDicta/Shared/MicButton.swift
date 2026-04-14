//
//  MicButton.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

/// Legacy orange onboarding mic button kept as a visual reference.
/// The keyboard onboarding now uses `OnboardingKeyboardMicButton`, which
/// matches the current mesh-gradient button from the keyboard target.
struct MicButton: View {
    var fontSize: CGFloat
    var padding: CGFloat
    var backgroundColor: Color
    var borderWidth: CGFloat

    var onTapAction: () -> Void

    var body: some View {
        Button {
            onTapAction()
        } label: {
            Image(systemName: "microphone.circle")
                .font(.system(size: fontSize))
                .foregroundStyle(.primary)
                .padding(padding)
                .background(backgroundColor.gradient, in: .circle)
                .background {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.teal, .pink, .teal],
                                center: .center,
                                angle: .degrees(isAnimating ? 360 : 0)
                            )
                        )
                        .blur(radius: 10)
                        .onAppear {
                            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                                isAnimating = true
                            }
                        }
                        .onDisappear {
                            isAnimating = false
                        }
                }
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.5), lineWidth: borderWidth)
                }
        }
    }

    @State private var isAnimating = false
}

#Preview {
    MicButton(
        fontSize: 34,
        padding: 6,
        backgroundColor: .orange.opacity(0.5),
        borderWidth: 0.5,
        onTapAction: {}
    )
}
