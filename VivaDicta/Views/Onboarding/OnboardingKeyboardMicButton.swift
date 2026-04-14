//
//  OnboardingKeyboardMicButton.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import SwiftUI

/// Main-app copy of the current keyboard target mic button styling.
/// Kept separate from the legacy `MicButton` so onboarding can match the
/// live keyboard UI without losing the older orange reference component.
struct OnboardingKeyboardMicButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let fontSize: CGFloat
    let padding: CGFloat
    let onTapAction: () -> Void

    var body: some View {
        Button {
            onTapAction()
        } label: {
            Image(systemName: "microphone.fill")
                .font(.system(size: fontSize))
                .foregroundStyle(.white)
                .padding(padding)
                .background(background)
        }
        .accessibilityLabel("Record")
    }

    @ViewBuilder
    private var background: some View {
        if #available(iOS 26, *) {
            styledBackground
                .glassEffect(.clear.interactive(), in: .circle)
        } else {
            styledBackground
        }
    }

    @ViewBuilder
    private var styledBackground: some View {
        if colorScheme == .dark {
            OnboardingKeyboardAnimatedMeshGradient()
                .mask(
                    Circle()
                        .stroke(lineWidth: 20)
                        .blur(radius: 6)
                )
                .blendMode(.lighten)
                .overlay(
                    Circle()
                        .stroke(lineWidth: 3)
                        .fill(Color.white)
                        .blur(radius: 2)
                        .blendMode(.overlay)
                )
                .overlay(
                    Circle()
                        .stroke(lineWidth: 1)
                        .fill(Color.white)
                        .blur(radius: 1)
                        .blendMode(.overlay)
                )
                .background(.black)
                .clipShape(.circle)
        } else {
            OnboardingKeyboardAnimatedMeshGradient2()
                .overlay(
                    Circle()
                        .stroke(lineWidth: 3)
                        .fill(Color.black.opacity(0.7))
                        .blur(radius: 2)
                        .blendMode(.overlay)
                )
                .overlay(
                    Circle()
                        .stroke(lineWidth: 1)
                        .fill(Color.black.opacity(1.0))
                        .blur(radius: 1)
                        .blendMode(.overlay)
                )
                .clipShape(.circle)
                .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 4)
        }
    }
}

private struct OnboardingKeyboardAnimatedMeshGradient: View {
    @State private var startDate = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(timeline.date.timeIntervalSince(startDate)) * 10
            MeshGradient(width: 3, height: 3, points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                [onboardingKeyboardSinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), onboardingKeyboardSinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
                [onboardingKeyboardSinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), onboardingKeyboardSinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
                [onboardingKeyboardSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), onboardingKeyboardSinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
                [onboardingKeyboardSinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), onboardingKeyboardSinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
                [onboardingKeyboardSinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), onboardingKeyboardSinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
                [onboardingKeyboardSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), onboardingKeyboardSinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
            ], colors: [
                .red, .purple, .indigo,
                .orange, .white, .blue,
                .yellow, .black, .mint
            ])
        }
    }
}

private struct OnboardingKeyboardAnimatedMeshGradient2: View {
    @State private var startDate = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(timeline.date.timeIntervalSince(startDate)) * 10
            MeshGradient(width: 3, height: 3, points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                [onboardingKeyboardSinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), onboardingKeyboardSinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
                [onboardingKeyboardSinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), onboardingKeyboardSinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
                [onboardingKeyboardSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), onboardingKeyboardSinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
                [onboardingKeyboardSinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), onboardingKeyboardSinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
                [onboardingKeyboardSinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), onboardingKeyboardSinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
                [onboardingKeyboardSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), onboardingKeyboardSinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
            ], colors: [
                .blue, .red, .orange,
                .orange, .indigo, .red,
                .cyan, .purple, .mint
            ])
        }
    }
}

private func onboardingKeyboardSinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
    let amplitude = (range.upperBound - range.lowerBound) / 2
    let midPoint = (range.upperBound + range.lowerBound) / 2
    return midPoint + amplitude * sin(timeScale * t + offset)
}

#Preview {
    OnboardingKeyboardMicButton(
        fontSize: 44,
        padding: 12,
        onTapAction: {}
    )
}
