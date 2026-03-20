//
//  OnboardingWelcomePage.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

struct OnboardingWelcomePage: View {
    @State private var startDate = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(startDate.distance(to: timeline.date))

            VStack(spacing: 0) {
                Spacer()

                Image("VivaDictaIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200)

                // Title
                VStack(spacing: 4) {
                    Text("Welcome to")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)

                    Text("VivaDicta")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(meshGradient(t: t))
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
                        icon: "checkmark.shield.fill",
                        iconStyle: Color.green,
                        text: "Complete privacy - your data stays on device"
                    )

                    OnboardingFeatureRow(
                        icon: "waveform",
                        iconStyle: MeshGradient(
                            width: 2,
                            height: 2,
                            points: [
                                [0, 0], [1, 0],
                                [0, 1], [1, 1]
                            ],
                            colors: [
                                .blue, .green,
                                .indigo, .teal
                            ]
                        ),
                        text: "Advanced transcription models for perfect accuracy"
                    )

                    OnboardingFeatureRow(
                        icon: "wand.and.stars",
                        iconStyle: MeshGradient(
                            width: 2,
                            height: 2,
                            points: [
                                [0, 0], [1, 0],
                                [0, 1], [1, 1]
                            ],
                            colors: [
                                .purple, .red,
                                .blue, .pink
                            ]
                        ),
                        text: "AI processing for professional results"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    private func meshGradient(t: Float) -> MeshGradient {
        MeshGradient(width: 3, height: 3, points: [
            .init(0, 0), .init(0.5, 0), .init(1, 0),
            [sinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), sinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), sinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), sinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
            [sinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), sinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), sinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), sinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
        ], colors: [
            .blue, .purple, .indigo,
            .cyan, .pink, .blue,
            .purple, .indigo, .cyan
        ])
    }

    private func sinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
    }
}

#Preview {
    OnboardingWelcomePage()
        .background(Color(.systemGroupedBackground))
}
