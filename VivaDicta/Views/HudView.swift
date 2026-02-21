
import SwiftUI

struct HudView: View {

    @Environment(\.colorScheme) var colorScheme

    var state: RecordingState
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
            HudViewLight(statusIcon: statusIcon, statusText: statusText, onCancel: onCancel)
        } else {
            HudViewDark(statusIcon: statusIcon, statusText: statusText, onCancel: onCancel)
        }
    }

}



struct HudContentView: View {

    var statusIcon: String
    var statusText: String
    var onCancel: (() -> Void)?

    @State private var isSymbolAnimating = false
    @State private var isShowing = false
    @State private var isShowingText = false
    @State private var showCancelButton = false
    @State private var timer: Timer?
    @State private var textRenderEffectTimer: Timer?
    @State private var cancelButtonTimer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            if #available(iOS 26.0, *) {
                if isShowing {
                    Image(systemName: statusIcon)
                        .transition(.asymmetric(insertion: .init(.symbolEffect(.drawOn)), removal: .opacity.combined(with: .scale(scale: 0.7))))
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                        .font(.system(size: 50, weight: .semibold))
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: 50, weight: .semibold))
                        .opacity(0)
                }
            } else { // iOS 18 option
                Image(systemName: statusIcon)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                    .font(.system(size: 50, weight: .semibold))
            }

            // Processing status label

            if isShowingText {
                Text(statusText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .customAttribute(EmphasisAttribute())
                    .transition(TextTransition())
                    .frame(width: 108, height: 24)
            } else {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 108, height: 24)
            }

            // Cancel button - appears after 1 second
            if showCancelButton, let onCancel {
                Button {
                    HapticManager.lightImpact()
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
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

            textRenderEffectTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                Task { @MainActor in
                    isShowingText = false

                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        isShowingText = true
                    }
                }
            }

            timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                Task { @MainActor in
                    isShowing = true

                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
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
            showCancelButton = false
            textRenderEffectTimer?.invalidate()
            textRenderEffectTimer = nil
            timer?.invalidate()
            timer = nil
            cancelButtonTimer?.invalidate()
            cancelButtonTimer = nil
        }
        .foregroundColor(.white)
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
    var onCancel: (() -> Void)?

    var body: some View {
        HudContentView(statusIcon: statusIcon, statusText: statusText, onCancel: onCancel)
            .background(
            AnimatedMeshGradient()
                .mask(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(lineWidth: 20)
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
        .background(.black)
        .mask(RoundedRectangle(cornerRadius: 30, style: .continuous))
        
    }
}

struct HudViewLight: View {

    var statusIcon: String
    var statusText: String
    var onCancel: (() -> Void)?

    var body: some View {
        HudContentView(statusIcon: statusIcon, statusText: statusText, onCancel: onCancel)
            .background(
            ZStack {
                AnimatedMeshGradient()
                    .mask(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(lineWidth: 16)
                            .blur(radius: 8)
                    )

                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(lineWidth: 3)
                            .fill(Color.white)
                            .blur(radius: 2)
                            .blendMode(.overlay)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(lineWidth: 1)
                            .fill(Color.white)
                            .blur(radius: 1)
                            .blendMode(.overlay)
                    )
            }
        )
        .background(
            ZStack {
                AnimatedMeshGradient()
                    .frame(width: 400, height: 800)
                    .opacity(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        )
        .background(.black)
        .clipShape(.rect(cornerRadius: 16))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 20)
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 15)
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
