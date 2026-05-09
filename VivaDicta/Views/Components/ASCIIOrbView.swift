//
//  ASCIIOrbView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.07
//

import SwiftUI

/// Audio-reactive ASCII-rendered orb. Drop-in alternative to `ParticleOrbView`:
/// same `audioPower` binding (0...1), same outer behavior. The orb is rendered
/// as a 50×50 grid of monospaced characters whose density follows a sphere
/// SDF + diffuse lighting + animated 3D value noise. Audio level drives noise
/// speed, density, color saturation, and a subtle radius pulse.
struct ASCIIOrbView: View {
    @Binding var audioPower: Double

    private let gridSize: Int = 40

    /// Ramp from light to dense. ~12 stops give a smooth shaded sphere
    /// without noticeable banding at this grid size.
    private static let ramp: [String] = [
        " ", ".", ":", "-", "=", "+", "*", "x", "#", "%", "&", "@"
    ]

    @State private var startTime: TimeInterval = 0
    @State private var smoothing = SmoothingState()

    /// Smoothing factor per second - lower = smoother/laggier, higher = snappier.
    private let smoothingSpeed: Double = 1.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let power = interpolatedPower(at: now)
            let elapsed = now - startTime

            Canvas(rendersAsynchronously: true) { context, size in
                drawOrb(in: &context, size: size, time: elapsed, power: power)
            }
        }
        .onAppear {
            startTime = Date.timeIntervalSinceReferenceDate
            smoothing.power = audioPower
        }
        .drawingGroup()
    }

    // MARK: - Rendering

    private func drawOrb(
        in context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        power: Double
    ) {
        let dim = min(size.width, size.height)
        guard dim > 0 else { return }

        let cellSize = dim / Double(gridSize)
        let centerX = size.width / 2
        let centerY = size.height / 2

        let halfDim = dim / 2
        let orbRadius = halfDim * (0.437 + power * 0.056)

        // Hard cull beyond the silhouette band. Cells in [edgeStart, edgeEnd]
        // get a soft, noise-perturbed alpha so the orb's edge feels fluid
        // instead of stamped at a perfect circle.
        let edgeStart = 0.80
        let edgeEnd = 1.15
        let edgeBand = edgeEnd - edgeStart
        let outerCullRadius = orbRadius * edgeEnd
        let outerCullSquared = outerCullRadius * outerCullRadius

        // Resolve each ramp glyph once per frame, then mutate `shading` per cell.
        let font = Font.system(size: cellSize * 1.30, weight: .medium, design: .monospaced)
        let resolvedRamp = Self.ramp.map { glyph in
            context.resolve(Text(glyph).font(font))
        }
        let lastIndex = resolvedRamp.count - 1

        // Explicit outward-radiating wave: sin(rNorm*freq - time*speed) creates
        // concentric rings whose phase advances inward over time, so each ring
        // visibly emerges at the center and expands toward the rim. Combined
        // with head-on lighting (so the brightest point is at the orb's screen
        // center, not upper-left), this reads unambiguously as center-out.
        let waveSpeed = 1.2 + power * 1.6
        let waveFrequency = 9.0
        let secondaryFrequency = 14.5
        let secondarySpeed = 1.9 + power * 1.2

        // Slow ambient time for the noise texture, independent of wave phase
        // so the rings don't smear into directional drift.
        let ambientTime = time * 0.40

        let densityBoost = 0.80 + power * 0.55

        for row in 0..<gridSize {
            let cy = (Double(row) + 0.5) * cellSize - halfDim
            for col in 0..<gridSize {
                let cx = (Double(col) + 0.5) * cellSize - halfDim
                let r2 = cx * cx + cy * cy
                if r2 > outerCullSquared { continue }

                // Project cell onto sphere. r2Norm can exceed 1 in the soft
                // edge halo - clamp so nz stays real but reads as "at silhouette".
                let nx = cx / orbRadius
                let ny = cy / orbRadius
                let r2Norm = nx * nx + ny * ny
                let nz2 = max(0.0, 1 - r2Norm)
                let nz = nz2.squareRoot()
                let rNorm = r2Norm.squareRoot()

                // Soft, noise-perturbed silhouette. Low-freq slow-evolving
                // noise pushes the effective radius in/out so the edge wobbles
                // organically, then smoothstep produces a gentle alpha falloff.
                let edgeNoise = Self.valueNoise3D(nx * 3.2, ny * 3.2, time * 0.45)
                let effRNorm = rNorm + (edgeNoise - 0.5) * 0.16

                var edgeAlpha = 1.0
                if effRNorm > edgeStart {
                    if effRNorm > edgeEnd { continue }
                    let t = (effRNorm - edgeStart) / edgeBand
                    let st = t * t * (3 - 2 * t)
                    edgeAlpha = 1 - st
                }

                // Head-on lighting: bright at center, dim toward edge. With the
                // light direction along +z, Lambertian diffuse simplifies to nz.
                let diffuse = nz

                // Two superimposed radial sine waves at different freqs/speeds.
                // The pattern at any cell depends only on rNorm and time, so
                // every ring of cells at the same radius pulses together; over
                // time the pulse rolls outward.
                let phase1 = rNorm * waveFrequency - time * waveSpeed
                let phase2 = rNorm * secondaryFrequency - time * secondarySpeed + 1.7
                let rawRipple = sin(phase1) + 0.55 * sin(phase2)
                let ripple = rawRipple / 1.55 * 0.5 + 0.5  // 0...1

                // Ambient noise texture - same time axis at every cell, so the
                // noise itself doesn't carry directional flow; only the wave does.
                let n0 = Self.valueNoise3D(nx * 2.5, ny * 2.5, ambientTime)
                let n1 = Self.valueNoise3D(
                    nx * 5.0 + 13.7,
                    ny * 5.0 - 7.2,
                    ambientTime * 1.4 + 4.1
                )
                let baseNoise = n0 * 0.65 + n1 * 0.35

                // Mix: texture under, ripple on top.
                let noise = baseNoise * 0.55 + ripple * 0.45

                // Rim glow at silhouette edges.
                let rimBase = 1 - nz
                let rim = rimBase * rimBase

                var lightness = diffuse * 0.40 + noise * 0.50 + rim * 0.10
                lightness *= edgeAlpha
                if lightness < 0 { lightness = 0 } else if lightness > 1 { lightness = 1 }
                lightness = pow(lightness, 0.85)
                lightness *= densityBoost
                if lightness > 1 { lightness = 1 }

                if lightness < 0.06 { continue }

                let charIndex = min(Int(lightness * Double(lastIndex)), lastIndex)
                var resolved = resolvedRamp[charIndex]
                resolved.shading = .color(Self.orbColor(lightness: lightness, audioPower: power))

                context.draw(resolved, at: CGPoint(x: centerX + cx, y: centerY + cy))
            }
        }
    }

    /// Exponential lerp toward audioPower each frame for smooth transitions.
    /// Mutates `smoothing` in place - non-observable so it doesn't trigger
    /// extra SwiftUI renders; TimelineView already drives the render cadence.
    private func interpolatedPower(at now: TimeInterval) -> Double {
        let dt: Double
        if smoothing.lastFrameTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(now - smoothing.lastFrameTime, 0.1)
        }
        let factor = 1.0 - exp(-smoothingSpeed * dt)
        smoothing.power += (audioPower - smoothing.power) * factor
        smoothing.lastFrameTime = now
        return smoothing.power
    }

    // MARK: - Noise

    /// Smoothstep-interpolated 3D value noise. Output range: 0...1.
    private static func valueNoise3D(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let xi = Int(floor(x))
        let yi = Int(floor(y))
        let zi = Int(floor(z))
        let xf = x - Double(xi)
        let yf = y - Double(yi)
        let zf = z - Double(zi)

        let u = xf * xf * (3 - 2 * xf)
        let v = yf * yf * (3 - 2 * yf)
        let w = zf * zf * (3 - 2 * zf)

        let c000 = hash3D(xi, yi, zi)
        let c100 = hash3D(xi + 1, yi, zi)
        let c010 = hash3D(xi, yi + 1, zi)
        let c110 = hash3D(xi + 1, yi + 1, zi)
        let c001 = hash3D(xi, yi, zi + 1)
        let c101 = hash3D(xi + 1, yi, zi + 1)
        let c011 = hash3D(xi, yi + 1, zi + 1)
        let c111 = hash3D(xi + 1, yi + 1, zi + 1)

        let x00 = c000 + (c100 - c000) * u
        let x10 = c010 + (c110 - c010) * u
        let x01 = c001 + (c101 - c001) * u
        let x11 = c011 + (c111 - c011) * u

        let y0 = x00 + (x10 - x00) * v
        let y1 = x01 + (x11 - x01) * v

        return y0 + (y1 - y0) * w
    }

    /// Integer hash producing pseudo-random Double in 0...1.
    private static func hash3D(_ x: Int, _ y: Int, _ z: Int) -> Double {
        var n = x &* 374761393 &+ y &* 668265263 &+ z &* 1274126177
        n = (n ^ (n >> 13)) &* 1274126177
        let masked = n & 0x7FFFFFFF
        return Double(masked) / Double(0x7FFFFFFF)
    }

    // MARK: - Color (cool→warm gradient, RGB-lerp inline to avoid Color.resolve overhead)

    private static func orbColor(lightness: Double, audioPower: Double) -> Color {
        let boosted = min(1.0, pow(audioPower, 0.3))
        let p = max(0.0, min(1.0, lightness * (0.4 + boosted * 0.6)))

        let r: Double, g: Double, b: Double
        if p < 0.25 {
            // cyan → green
            let t = p / 0.25
            r = lerp(0.32, 0.20, t)
            g = lerp(0.76, 0.78, t)
            b = lerp(0.93, 0.35, t)
        } else if p < 0.5 {
            // green → yellow
            let t = (p - 0.25) / 0.25
            r = lerp(0.20, 1.00, t)
            g = lerp(0.78, 0.80, t)
            b = lerp(0.35, 0.00, t)
        } else if p < 0.7 {
            // yellow → orange
            let t = (p - 0.5) / 0.2
            r = 1.0
            g = lerp(0.80, 0.58, t)
            b = 0.0
        } else {
            // orange → red
            let t = (p - 0.7) / 0.3
            r = 1.0
            g = lerp(0.58, 0.23, t)
            b = lerp(0.00, 0.19, t)
        }

        return Color(red: r, green: g, blue: b)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}

// MARK: - Smoothing State

/// Reference type for frame-timing - mutations persist across renders without
/// triggering SwiftUI invalidation (not @Observable). Mirrors the pattern used
/// in `ParticleOrbView`.
private final class SmoothingState {
    var power: Double = 0
    var lastFrameTime: TimeInterval = 0
}

#if DEBUG || QA
#Preview {
    struct PreviewWrapper: View {
        @State private var power = 0.3

        var body: some View {
            VStack {
                ASCIIOrbView(audioPower: $power)
                    .frame(width: 320, height: 320)
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
