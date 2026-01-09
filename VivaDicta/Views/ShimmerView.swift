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

/// A view modifier that applies an animated wave distortion effect using Metal shader.
struct WaveModifier: ViewModifier {
    let startTime: Date
    var speed: Float = 8
    var smoothing: Float = 15
    var strength: Float = 3

    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            content
                .distortionEffect(
                    ShaderLibrary.wave(
                        .float(context.date.timeIntervalSince(startTime)),
                        .float(speed),
                        .float(smoothing),
                        .float(strength)
                    ),
                    maxSampleOffset: CGSize(width: 0, height: CGFloat(strength) * 2)
                )
        }
    }
}

/// A view modifier that applies a water ripple distortion effect using Metal shader.
struct WaterModifier: ViewModifier {
    let startTime: Date
    var speed: Float = 3
    var strength: Float = 3
    var frequency: Float = 10

    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            content
                .distortionEffect(
                    ShaderLibrary.water(
                        .float2(1, 1),
                        .float(context.date.timeIntervalSince(startTime)),
                        .float(speed),
                        .float(strength),
                        .float(frequency)
                    ),
                    maxSampleOffset: CGSize(width: CGFloat(strength), height: CGFloat(strength))
                )
        }
    }
}

/// A view modifier that conditionally applies the wave distortion effect.
struct ConditionalShimmer: ViewModifier {
    let isActive: Bool
    @State private var startTime: Date?

    func body(content: Content) -> some View {
        if isActive {
            if let startTime {
                content.modifier(WaterModifier(startTime: startTime))
            } else {
                content
                    .onAppear {
                        startTime = Date()
                    }
            }
        } else {
            content
                .onChange(of: isActive) { _, newValue in
                    if !newValue {
                        startTime = nil
                    }
                }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        Text("Wave distortion effect!")
            .font(.title)
            .bold()
            .modifier(WaveModifier(startTime: Date()))

        Text("Water ripple effect!")
            .font(.title)
            .bold()
            .modifier(WaterModifier(startTime: Date()))

        Text("Rainbow gradient effect!")
            .font(.title)
            .bold()
            .modifier(AnimatedGradientModifier(startTime: Date()))

        Text("Regular text without effect")
            .font(.title)
            .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.2))
}
