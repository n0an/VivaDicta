//
//  ShimmerView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.09
//

import SwiftUI

/// A view modifier that applies an animated wave distortion effect using Metal shader.
struct WaveModifier: ViewModifier {
    let startTime: Date
    var speed: Float = 8
    var smoothing: Float = 1
    var strength: Float = 1

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

/// A view modifier that conditionally applies the wave distortion effect.
struct ConditionalShimmer: ViewModifier {
    let isActive: Bool
    @State private var startTime: Date?

    func body(content: Content) -> some View {
        Group {
            if isActive, let startTime {
                content.modifier(WaveModifier(startTime: startTime))
            } else {
                content
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startTime = Date()
            } else {
                startTime = nil
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

        Text("Regular text without effect")
            .font(.title)
            .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.2))
}
