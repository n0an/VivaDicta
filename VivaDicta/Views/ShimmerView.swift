//
//  ShimmerView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.09
//

import SwiftUI

/// A view modifier that applies an animated rainbow gradient effect using Metal shader.
struct AnimatedGradientModifier: ViewModifier {
    let startTime: Date

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let elapsedTime = timeline.date.timeIntervalSince(startTime)

            content
                .colorEffect(
                    ShaderLibrary.animatedGradientFill(
                        .float2(1, 1),
                        .float(elapsedTime)
                    )
                )
        }
    }
}

/// A view modifier that conditionally applies the animated gradient effect.
struct ConditionalShimmer: ViewModifier {
    let isActive: Bool
    @State private var startTime: Date?

    func body(content: Content) -> some View {
        if isActive {
            if let startTime {
                content.modifier(AnimatedGradientModifier(startTime: startTime))
            } else {
                content
                    .onAppear {
                        startTime = Date()
                    }
            }
        } else {
            content
                .onAppear {
                    startTime = nil
                }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Rainbow shimmer effect!")
            .font(.title)
            .bold()
            .modifier(AnimatedGradientModifier(startTime: Date()))

        Text("Regular text without shimmer")
            .font(.title)
            .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.2))
}
