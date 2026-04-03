//
//  WatchRecordView.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import SwiftUI
import WatchKit

struct WatchRecordView: View {
    let viewModel: WatchRecordViewModel
    @State private var isGlowAnimating = false

    var body: some View {
        GeometryReader { geometry in
            let buttonSize = geometry.size.width * 0.5

            VStack(spacing: 12) {
                Spacer()

                mainButton(size: buttonSize)

                if viewModel.state == .recording {
                    Text(formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                transferStatusView

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }



    private func mainButton(size: CGFloat) -> some View {
        Button(action: viewModel.toggleRecording) {
            Image(systemName: viewModel.state == .idle ? "microphone.circle" : "stop.circle.fill")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(.primary)
                .font(.system(size: size))
                .padding(6)
                .glassEffectColor(isInteractive: true, color: viewModel.state == .idle ? .orange : .red, opacity: 0.8)
                .background {
                    Circle()
                        .fill(AngularGradient(
                            colors: viewModel.state == .idle ? [.teal, .pink, .teal] : [.orange, .green, .orange],
                            center: .center,
                            angle: .degrees(isGlowAnimating ? 360 : 0)
                        ))
                        .blur(radius: 20)
                        .onAppear {
                            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                                isGlowAnimating = true
                            }
                        }
                        .onDisappear {
                            isGlowAnimating = false
                        }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var transferStatusView: some View {
        switch viewModel.transferStatus {
        case .idle:
            EmptyView()

        case .transferring(let count):
            Label("Uploading \(count) \(count == 1 ? "file" : "files")", systemImage: "icloud.and.arrow.up")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .transition(.opacity)

        case .allUploaded:
            Label("All uploaded", systemImage: "checkmark.icloud")
                .font(.caption2)
                .foregroundStyle(.green)
                .transition(.opacity)

        case .error(let message):
            Label(message, systemImage: "exclamationmark.icloud")
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
                .transition(.opacity)
        }
    }

    private var formattedDuration: String {
        Duration.seconds(viewModel.recordingDuration)
            .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }
}


struct GlassEffectColorModifier: ViewModifier {
    var isInteractive: Bool
    var color: Color
    var opacity: Double
    
    func body(content: Content) -> some View {
        if #available(watchOS 26, *){
            content
                .glassEffect(.regular.tint(color.opacity(opacity)).interactive(isInteractive))
        } else {
            content
                .background(color.gradient, in: .circle)
        }
    }
}

extension View {
    func glassEffectColor(isInteractive: Bool = true,
                          color: Color = .clear,
                          opacity: Double) -> some View {
        modifier(GlassEffectColorModifier(
            isInteractive: isInteractive,
            color: color,
            opacity: opacity))
    }
}
