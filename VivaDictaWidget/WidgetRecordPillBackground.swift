//
//  WidgetRecordPillBackground.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2026.04.19
//

import SwiftUI

/// Mesh-gradient pill that mirrors the main screen mic button's
/// AnimatedMeshGradient background. Widgets can't run TimelineView,
/// so `t` is driven by the widget's timeline entry — the background
/// shifts subtly across the day as entries refresh hourly.
struct WidgetRecordPillBackground: View {
    let cornerRadius: CGFloat
    let colorScheme: ColorScheme
    let t: Float

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        let gradient = StaticWidgetMeshGradient(colors: meshColors, t: t)
            .mask(
                shape
                    .stroke(lineWidth: 26)
                    .blur(radius: 6)
            )
            .blendMode(colorScheme == .dark ? .lighten : .normal)

        Group {
            if colorScheme == .dark {
                gradient
                    .overlay(
                        shape
                            .stroke(lineWidth: 3)
                            .fill(Color.white)
                            .blur(radius: 2)
                            .blendMode(.overlay)
                    )
                    .overlay(
                        shape
                            .stroke(lineWidth: 1)
                            .fill(Color.white)
                            .blur(radius: 1)
                            .blendMode(.overlay)
                    )
                    .background(Color.black)
            } else {
                gradient
                    .overlay(
                        shape
                            .stroke(lineWidth: 3)
                            .fill(Color.black.opacity(0.7))
                            .blur(radius: 2)
                            .blendMode(.overlay)
                    )
                    .overlay(
                        shape
                            .stroke(lineWidth: 1)
                            .fill(Color.black)
                            .blur(radius: 1)
                            .blendMode(.overlay)
                    )
                    .background(Color.white)
            }
        }
        .clipShape(shape)
    }

    private var meshColors: [Color] {
        if colorScheme == .dark {
            [
                .red, .purple, .indigo,
                .orange, .white, .blue,
                .yellow, .black, .mint
            ]
        } else {
            [
                .blue, .red, .orange,
                .orange, .indigo, .red,
                .cyan, .purple, .mint
            ]
        }
    }
}

private struct StaticWidgetMeshGradient: View {
    let colors: [Color]
    let t: Float

    var body: some View {
        MeshGradient(width: 3, height: 3, points: [
            .init(0, 0), .init(0.5, 0), .init(1, 0),
            [sinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t),
             sinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t),
             sinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t),
             sinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
            [sinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t),
             sinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
            [sinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t),
             sinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
            [sinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t),
             sinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
        ], colors: colors)
    }

    private func sinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
    }
}
