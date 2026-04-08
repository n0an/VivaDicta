//
//  ParticleOrbView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.08
//

import SwiftUI

struct ParticleOrbView: View {
    @Binding var audioPower: Double

    private let particleCount = 80
    @State private var particles: [Firefly] = []
    @State private var displayPower: Double = 0
    @State private var lastFrameTime: TimeInterval = 0
    @State private var startTime: TimeInterval = 0

    /// Smoothing factor per second — lower = smoother/laggier, higher = snappier
    private let smoothingSpeed: Double = 1.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let power = interpolatedPower(at: now)

            let elapsed = now - startTime

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for particle in particles {
                    let pos = particle.position(at: elapsed, power: power, center: center)
                    let blink = particle.blinkIntensity(at: elapsed)
                    let color = Self.particleColor(for: power, seed: particle.colorSeed)
                    let alpha = particle.opacity * blink
                    let size = particle.size * (0.8 + power * 0.6) * (0.5 + blink * 0.5)

                    let rect = CGRect(
                        x: pos.x - size / 2,
                        y: pos.y - size / 2,
                        width: size,
                        height: size
                    )

                    // Outer glow
                    let glowSize = size * 3
                    let particleGlowRect = CGRect(
                        x: pos.x - glowSize / 2,
                        y: pos.y - glowSize / 2,
                        width: glowSize,
                        height: glowSize
                    )
                    context.fill(
                        Path(ellipseIn: particleGlowRect),
                        with: .color(color.opacity(alpha * 0.15))
                    )

                    // Core
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(alpha * (0.5 + power * 0.5)))
                    )
                }
            }
        }
        .onAppear {
            startTime = Date.timeIntervalSinceReferenceDate
            particles = (0..<particleCount).map { _ in Firefly.random() }
            displayPower = audioPower
        }
        .drawingGroup()
    }

    /// Exponential lerp toward audioPower each frame for smooth, continuous transitions
    private func interpolatedPower(at now: TimeInterval) -> Double {
        let dt: Double
        if lastFrameTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(now - lastFrameTime, 0.1) // cap to avoid jumps after backgrounding
        }

        // Exponential smoothing: displayPower moves toward audioPower
        let factor = 1.0 - exp(-smoothingSpeed * dt)
        let newPower = displayPower + (audioPower - displayPower) * factor

        // Mutate state on next run loop tick to avoid "modifying state during view update"
        DispatchQueue.main.async {
            displayPower = newPower
            lastFrameTime = now
        }

        return newPower
    }

    // MARK: - Color Mapping

    private static func particleColor(for power: Double, seed: Double) -> Color {
        // Apply curve to make colors reach "hot" faster
        let boosted = min(1, pow(power, 0.55))
        let shift = (seed - 0.5) * 0.12
        let p = min(1, max(0, boosted + shift))

        if p < 0.2 {
            let t = p / 0.2
            return blend(.blue, .cyan, t: t)
        } else if p < 0.4 {
            let t = (p - 0.2) / 0.2
            return blend(.cyan, .green, t: t)
        } else if p < 0.6 {
            let t = (p - 0.4) / 0.2
            return blend(.green, .yellow, t: t)
        } else if p < 0.8 {
            let t = (p - 0.6) / 0.2
            return blend(.yellow, .orange, t: t)
        } else {
            let t = (p - 0.8) / 0.2
            return blend(.orange, .red, t: t)
        }
    }

    private static func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        let resolved1 = a.resolve(in: EnvironmentValues())
        let resolved2 = b.resolve(in: EnvironmentValues())
        return Color(
            red: Double(resolved1.red) + Double(resolved2.red - resolved1.red) * t,
            green: Double(resolved1.green) + Double(resolved2.green - resolved1.green) * t,
            blue: Double(resolved1.blue) + Double(resolved2.blue - resolved1.blue) * t
        )
    }
}

// MARK: - Firefly Particle

private struct Firefly {
    let baseAngle: Double        // radians, home position on circle
    let angularSpeed: Double     // radians/sec, orbit speed
    let baseRadius: Double       // distance from center at rest
    let wanderAmplitude: Double  // how far it drifts from baseRadius
    let wanderFrequency: Double  // oscillation speed for radial wander
    let wanderPhase: Double      // phase offset
    let tangentialWander: Double  // lateral drift amplitude
    let tangentialPhase: Double
    let size: Double
    let opacity: Double
    let colorSeed: Double
    let phaseOffset: Double      // time offset for organic feel
    let blinkFrequency: Double   // how fast it blinks (cycles/sec)
    let blinkPhase: Double       // phase offset so they don't blink in sync

    /// Returns 0...1 blink intensity — smoothly fades in and out
    func blinkIntensity(at elapsed: Double) -> Double {
        let t = elapsed + blinkPhase
        // sin produces -1...1, remap to 0...1 with a bias toward visible
        let raw = sin(t * blinkFrequency * 2 * .pi)
        return 0.5 + 0.5 * raw // range: 0...1
    }

    func position(at elapsed: Double, power: Double, center: CGPoint) -> CGPoint {
        let t = elapsed + phaseOffset

        // Orbit — base speed only, power doesn't multiply time to avoid jumps
        let currentAngle = baseAngle + angularSpeed * t

        // Base radius expands with power
        let radius = baseRadius * (0.6 + power * 0.8)

        // Radial wander — particles drift further out with power
        let wanderScale = 1.0 + power * 2.5
        let radialOffset = wanderAmplitude * wanderScale * sin(wanderFrequency * t + wanderPhase)

        // Tangential wander for organic feel
        let tangOffset = tangentialWander * (0.5 + power * 1.0) * sin(wanderFrequency * 0.7 * t + tangentialPhase)

        let finalRadius = radius + radialOffset
        let finalAngle = currentAngle + tangOffset / max(finalRadius, 1)

        let x = center.x + cos(finalAngle) * finalRadius
        let y = center.y + sin(finalAngle) * finalRadius

        return CGPoint(x: x, y: y)
    }

    static func random() -> Firefly {
        Firefly(
            baseAngle: .random(in: 0...(2 * .pi)),
            angularSpeed: .random(in: 0.1...0.6) * (Bool.random() ? 1 : -1),
            baseRadius: .random(in: 30...55),
            wanderAmplitude: .random(in: 5...20),
            wanderFrequency: .random(in: 0.5...2.0),
            wanderPhase: .random(in: 0...(2 * .pi)),
            tangentialWander: .random(in: 3...12),
            tangentialPhase: .random(in: 0...(2 * .pi)),
            size: .random(in: 2...6),
            opacity: .random(in: 0.4...1.0),
            colorSeed: .random(in: 0...1),
            phaseOffset: .random(in: 0...100),
            blinkFrequency: .random(in: 0.3...0.8),
            blinkPhase: .random(in: 0...(2 * .pi))
        )
    }
}

#if DEBUG || QA
#Preview {
    struct PreviewWrapper: View {
        @State private var power = 0.3

        var body: some View {
            VStack {
                ParticleOrbView(audioPower: $power)
                    .frame(width: 200, height: 200)
                    .background(.black)
                    .clipShape(.rect(cornerRadius: 20))

                Slider(value: $power, in: 0...1)
                    .padding()

                Text("Power: \(power, format: .number.precision(.fractionLength(2)))")
            }
        }
    }
    return PreviewWrapper()
}
#endif
