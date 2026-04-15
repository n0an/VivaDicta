
import SwiftUI

struct HudView: View {

    @Environment(\.colorScheme) var colorScheme

    var state: RecordingState
    var detailText: String? = nil
    var progress: Double? = nil
    var onCancel: (() -> Void)?

    var statusIcon: String {
        switch state {
        case .transcribing:
            return "pencil.and.scribble"
        case .enhancing:
            return "sparkles"
        default:
            return "microphone.circle.fill"
        }
    }

    var statusText: String {
        switch state {
        case .transcribing:
            return "Transcribing"
        case .enhancing:
            return "AI Processing"
        default:
            return ""
        }
    }

    var body: some View {

        if colorScheme == .light {
            HudViewLight(
                statusIcon: statusIcon,
                statusText: statusText,
                detailText: detailText,
                progress: progress,
                onCancel: onCancel
            )
        } else {
            HudViewDark(
                statusIcon: statusIcon,
                statusText: statusText,
                detailText: detailText,
                progress: progress,
                onCancel: onCancel
            )
        }
    }

}

private struct HudStatusSymbolView: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemName: String
    let size: CGFloat

    var body: some View {
        let symbol = Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))

        Group {
            if colorScheme == .dark {
                symbol
                    .foregroundStyle(.white)
            } else {
                HudLocalMeshGradient()
                    .frame(width: size + 28, height: size + 28)
                    .mask { symbol }
                    .overlay {
                        Color.black.opacity(0.3)
                            .mask { symbol }
                    }
            }
        }
        .frame(width: size + 28, height: size + 28)
    }
}

private struct HudLocalMeshGradient: View {
    @State private var startDate = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = Float(timeline.date.timeIntervalSince(startDate)) * 10
            MeshGradient(width: 3, height: 3, points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                [hudSinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), hudSinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
                [hudSinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), hudSinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
                [hudSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), hudSinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
                [hudSinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), hudSinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
                [hudSinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), hudSinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
                [hudSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), hudSinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
            ], colors: [
                .red, .purple, .indigo,
                .orange, .white, .blue,
                .yellow, .black, .mint
            ])
        }
        .background(
            LinearGradient(
                colors: [.red, .purple, .indigo, .blue, .mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 12))
    }

    private func hudSinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
        let amplitude = (range.upperBound - range.lowerBound) / 2
        let midPoint = (range.upperBound + range.lowerBound) / 2
        return midPoint + amplitude * sin(timeScale * t + offset)
    }
}

private struct HudStatusTextView: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String

    var body: some View {
        let label = Text(text)
            .font(.system(size: 17, weight: .semibold))

        Group {
            if colorScheme == .dark {
                label
                    .foregroundStyle(.primary)
            } else {
                AnimatedMeshGradient()
                    .mask { label }
                    .overlay {
                        Color.black.opacity(0.35)
                            .mask { label }
                    }
            }
        }
    }
}

struct HudContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    var statusIcon: String
    var statusText: String
    var detailText: String?
    var progress: Double?
    var onCancel: (() -> Void)?

    @State private var isSymbolAnimating = false
    @State private var isShowing = false
    @State private var isShowingText = false
    @State private var showCancelButton = false
    @State private var timer: Timer?
    @State private var cancelButtonTimer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            if #available(iOS 26.0, *) {
                if isShowing {
                    HudStatusSymbolView(systemName: statusIcon, size: 50)
                        .transition(.asymmetric(insertion: .init(.symbolEffect(.drawOn)), removal: .opacity.combined(with: .scale(scale: 0.7))))
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                } else {
                    HudStatusSymbolView(systemName: statusIcon, size: 50)
                        .opacity(0)
                }
            } else { // iOS 18 option
                HudStatusSymbolView(systemName: statusIcon, size: 50)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
            }

            // Processing status label

            if isShowingText {
                HudStatusTextView(text: statusText)
                    .transition(
                        .asymmetric(
                            insertion: .move(
                                edge: .bottom
                            )
                            .combined(
                                with: .scale(
                                    scale: 0.5
                                )
                            ),
                            removal: .opacity
                        )
                    )
                    .frame(width: 140, height: 24)
            } else {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 140, height: 24)
            }

            if let detailText {
                Text(detailText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 180, height: 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let progress {
                ProgressView(value: progress)
                    .tint(colorScheme == .dark ? .white.opacity(0.85) : .black.opacity(0.5))
                    .frame(width: 180)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Cancel button - appears after 1 second
            if showCancelButton, let onCancel {
                Button {
                    HapticManager.lightImpact()
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.8) : .primary.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.08), in: .capsule)
                        .overlay {
                            if colorScheme == .light {
                                Capsule()
                                    .stroke(.black.opacity(0.12), lineWidth: 1)
                            }
                        }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(0.5)))
            }
        }
        .animation(.default, value: isShowingText)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showCancelButton)
        .onChange(of: statusText) { _, _ in
            // Reset cancel button timer when state changes (e.g., transcribing -> enhancing)
            resetCancelButtonTimer()
        }
        .onAppear {
            isSymbolAnimating = true
            isShowingText = true
            resetCancelButtonTimer()

            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                Task { @MainActor in
                    isShowing = true

                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2.6))
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowing = false
                        }
                    }
                }
            }
            timer?.fire()
        }
        .onDisappear {
            isSymbolAnimating = false
            isShowingText = false
            showCancelButton = false
            timer?.invalidate()
            timer = nil
            cancelButtonTimer?.invalidate()
            cancelButtonTimer = nil
        }
        .padding()
    }

    private func resetCancelButtonTimer() {
        showCancelButton = false
        cancelButtonTimer?.invalidate()
        cancelButtonTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task { @MainActor in
                showCancelButton = true
            }
        }
    }
}

struct HudViewDark: View {

    var statusIcon: String
    var statusText: String
    var detailText: String?
    var progress: Double?
    var onCancel: (() -> Void)?

    var body: some View {
        return HudContentView(
            statusIcon: statusIcon,
            statusText: statusText,
            detailText: detailText,
            progress: progress,
            onCancel: onCancel
        )
        .background(
            AnimatedMeshGradient()
                .mask(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(lineWidth: 26)
                        .blur(radius: 10)
                )
                .blendMode(.lighten)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(lineWidth: 3)
                .fill(Color.white)
                .blur(radius: 2)
                .blendMode(.overlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(lineWidth: 1)
                .fill(Color.white)
                .blur(radius: 1)
                .blendMode(.overlay)
        )
//        .background(.black)
        .clipShape(.rect(cornerRadius: 30))
        .applyHudGlassEffect(cornerRadius: 30, isInteractive: onCancel != nil)
    }
}

struct HudViewLight: View {

    var statusIcon: String
    var statusText: String
    var detailText: String?
    var progress: Double?
    var onCancel: (() -> Void)?

    var body: some View {
        let lightBackground = AnimatedMeshGradient2()
            .mask(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(lineWidth: 30)
                    .blur(radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(lineWidth: 3)
                    .fill(Color.black.opacity(0.7))
                    .blur(radius: 2)
                    .blendMode(.overlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(lineWidth: 1)
                    .fill(Color.black.opacity(1.0))
                    .blur(radius: 1)
                    .blendMode(.overlay)
            )

        return HudContentView(
            statusIcon: statusIcon,
            statusText: statusText,
            detailText: detailText,
            progress: progress,
            onCancel: onCancel
        )
        .background(lightBackground)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 4)
        .applyHudGlassEffect(cornerRadius: 16, isInteractive: onCancel != nil)
    }
}

private struct HudGlassEffectModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if colorScheme == .light {
                content
                    .glassEffect(.regular.interactive(isInteractive), in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .glassEffect(.clear.interactive(isInteractive), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
        }
    }
}

extension View {
    fileprivate func applyHudGlassEffect(cornerRadius: CGFloat, isInteractive: Bool) -> some View {
        modifier(HudGlassEffectModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
}

#Preview("Light") {
    VStack(spacing: 60) {
        HudView(state: .transcribing)
        HudView(state: .enhancing)
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: 60) {
        HudView(state: .transcribing)
        HudView(state: .enhancing)
    }
    .preferredColorScheme(.dark)
}
