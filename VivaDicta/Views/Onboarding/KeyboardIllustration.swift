//
//  KeyboardIllustration.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

// MARK: - Keyboard Illustration

struct KeyboardIllustration: View {

    @State var animate: Bool = false

    var body: some View {
        Image("KeyboardImage")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 350)
            .overlay(alignment: .topTrailing) {
                OnboardingKeyboardMicButton(
                    fontSize: 34,
                    padding: 24,
                    onTapAction: {}
                )
                .scaleEffect(animate ? 1.5 : 1.0)
                .offset(x: 16, y: -20)
                .onAppear {
                    animate = false

                    withAnimation(.spring.delay(1.0)) {
                        animate = true

                        Task {
                            try await Task.sleep(for: .seconds(1.3))
                            withAnimation {
                                animate = false
                            }
                        }
                    }
                }
            }
    }
}
