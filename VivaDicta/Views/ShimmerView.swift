//
//  ShimmerView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.09
//

import SwiftUI

/// A view modifier that applies an animated water distortion effect using Metal shader.
/// Creates a fluid ripple effect that distorts both X and Y coordinates.
struct WaterModifier: ViewModifier {
    let startTime: Date
    var speed: Float = 3
    var strength: Float = 3
    var frequency: Float = 10

    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSince(startTime)

            content
                .visualEffect { content, proxy in
                    content
                        .distortionEffect(
                            ShaderLibrary.water(
                                .float2(proxy.size),
                                .float(time),
                                .float(speed),
                                .float(strength),
                                .float(frequency)
                            ),
                            maxSampleOffset: CGSize(width: 100, height: 100)
                        )
                }
        }
    }
}

/// A view modifier that applies an animated grayscale gradient sweep effect using Metal shader.
/// Creates a wave of brightness that sweeps across the content.
struct GrayscaleGradientModifier: ViewModifier {
    var xOffset: Float
    var animatableData: Float {
        get { xOffset }
        set { xOffset = newValue }
    }

    func body(content: Content) -> some View {
        content
            .visualEffect { content, proxy in
                content
                    .colorEffect(
                        ShaderLibrary.grayscaleGradient(
                            .float2(proxy.size),
                            .float(xOffset)
                        )
                    )
            }
    }
}

/// A view modifier that conditionally applies the water distortion effect.
struct ConditionalShimmer: ViewModifier {
    let isActive: Bool
    @State private var startTime: Date?

    func body(content: Content) -> some View {
        Group {
            if isActive, let startTime {
                content.modifier(WaterModifier(startTime: startTime))
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
    @Previewable @State var isShimmering = false

    VStack(spacing: 40) {
        Text("Grayscale gradient effect!")
            .font(.title)
            .bold()
            .modifier(ConditionalShimmer(isActive: isShimmering))

        Text("Water distortion effect!")
            .font(.title)
            .bold()
            .modifier(WaterModifier(startTime: Date()))

        Button("Toggle Shimmer") {
            isShimmering.toggle()
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.2))
}
