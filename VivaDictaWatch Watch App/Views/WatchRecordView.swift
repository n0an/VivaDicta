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

                recordButton(size: buttonSize)

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

    @ViewBuilder
    private func recordButton(size: CGFloat) -> some View {
        switch viewModel.state {
        case .idle:
            micButton(size: size)
        case .recording:
            stopButton(size: size)
        }
    }

    private func micButton(size: CGFloat) -> some View {
        Button(action: viewModel.toggleRecording) {
            Image(systemName: "microphone.circle")
                .foregroundStyle(.primary)
                .font(.system(size: size))
                .padding(6)
                .background(Color.orange.opacity(0.9).gradient, in: .circle)
                .background {
                    Circle()
                        .fill(AngularGradient(
                            colors: [.teal, .pink, .teal],
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
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.5), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }

    private func stopButton(size: CGFloat) -> some View {
        Button(action: viewModel.toggleRecording) {
            Image(systemName: "stop.circle.fill")
                .foregroundStyle(.white)
                .font(.system(size: size))
                .padding(6)
                .background(Color.red.gradient, in: .circle)
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.5), lineWidth: 0.5)
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

        case .allUploaded:
            Label("All uploaded", systemImage: "checkmark.icloud")
                .font(.caption2)
                .foregroundStyle(.green)

        case .error(let message):
            Label(message, systemImage: "exclamationmark.icloud")
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    private var formattedDuration: String {
        Duration.seconds(viewModel.recordingDuration)
            .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }
}
