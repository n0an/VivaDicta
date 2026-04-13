//
//  WatchRecordView.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import SwiftUI
import WatchKit

struct WatchRecordView: View {
    @Bindable var viewModel: WatchRecordViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
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
            .offset(y: -8)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(to: newPhase)
        }
        .toolbar {
            if !viewModel.availableModes.isEmpty {
                if viewModel.state == .idle {
                    ToolbarItem(placement: .topBarLeading) {
                        modePicker
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Color.clear
                    }
                }
            }
        }
    }


    private func mainButton(size: CGFloat) -> some View {
        Button(action: viewModel.toggleRecording) {
            Image(systemName: viewModel.state == .idle ? "microphone.fill" : "stop.circle.fill")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(.primary)
                .font(.system(size: 50))
                .frame(width: size, height: size)
                .background {
                    ZStack {
                        mainButtonGlow(size: size)
                        mainButtonBackground
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("WatchRecordView.mainButton")
    }

    @ViewBuilder
    private var mainButtonBackground: some View {
        if viewModel.state == .idle {
            idleButtonBackground
        } else {
            stopButtonBackground
        }
    }

    @ViewBuilder
    private var idleButtonBackground: some View {
        
        let darkBackground = WatchAnimatedMeshGradient()
            .mask(
                Circle()
                    .stroke(lineWidth: 22)
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
            .clipShape(.circle)
        
        
        
        if #available(watchOS 26, *) {
            darkBackground
                .glassEffect(.clear.interactive())
        } else {
            darkBackground
        }
        
    }

    @ViewBuilder
    private func mainButtonGlow(size: CGFloat) -> some View {
        if viewModel.state == .idle {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.teal, .pink, .teal],
                        center: .center,
                        angle: .degrees(isGlowAnimating ? 360 : 0)
                    )
                )
                .mask {
                    Circle()
                        .stroke(lineWidth: size * 0.16)
                        .blur(radius: size * 0.04)
                }
                .scaleEffect(1.04)
                .blur(radius: size * 0.09)
                .opacity(0.95)
                .onAppear {
                    withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                        isGlowAnimating = true
                    }
                }
                .onDisappear {
                    isGlowAnimating = false
                }
        } else {
            AngularGradient(
                colors: [.orange, .red, .pink, .orange],
                center: .center
            )
            .mask {
                Circle()
                    .stroke(lineWidth: size * 0.16)
                    .blur(radius: size * 0.04)
            }
            .scaleEffect(1.04)
            .blur(radius: size * 0.09)
            .opacity(0.9)
        }
    }

    @ViewBuilder
    private var stopButtonBackground: some View {
        if #available(watchOS 26, *) {
            Circle()
//                .fill(.red.opacity(0.85))
                .glassEffect(.regular.tint(.red.opacity(0.85)).interactive(), in: .circle)
        } else {
            Circle()
                .fill(.red.gradient)
        }
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

    private var modePicker: some View {
        let selectedName = viewModel.availableModes.first { $0.id == viewModel.selectedModeId }?.name
            ?? viewModel.availableModes.first?.name ?? "Default"

        return NavigationLink {
            List(viewModel.availableModes) { mode in
                Button {
                    viewModel.selectedModeId = mode.id
                } label: {
                    HStack {
                        Text(mode.name)
                        Spacer()
                        if mode.id == viewModel.selectedModeId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .accessibilityIdentifier("WatchRecordView.modeRow.\(mode.id)")
            }
            .navigationTitle("Mode")
            .onAppear {
                WKInterfaceDevice.current().play(.click)
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 16, weight: .semibold))
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedModeId)
        .accessibilityIdentifier("WatchRecordView.modePicker")
    }

    private var formattedDuration: String {
        Duration.seconds(viewModel.recordingDuration)
            .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }
}

private struct WatchAnimatedMeshGradient: View {
    @State private var startDate = Date.now

    @ViewBuilder
    var body: some View {
        if #available(watchOS 11, *) {
            TimelineView(.animation) { timeline in
                let t = Float(timeline.date.timeIntervalSince(startDate)) * 10
                MeshGradient(width: 3, height: 3, points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    [watchSinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), watchSinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
                    [watchSinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), watchSinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
                    [watchSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), watchSinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
                    [watchSinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), watchSinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
                    [watchSinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), watchSinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
                    [watchSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), watchSinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
                ], colors: [
                    .red, .purple, .indigo,
                    .orange, .white, .blue,
                    .yellow, .black, .mint
                ])
            }
        } else {
            AngularGradient(
                colors: [.red, .purple, .indigo, .blue, .mint, .orange, .red],
                center: .center
            )
        }
    }
}

private struct WatchAnimatedMeshGradient2: View {
    @State private var startDate = Date.now

    @ViewBuilder
    var body: some View {
        if #available(watchOS 11, *) {
            TimelineView(.animation) { timeline in
                let t = Float(timeline.date.timeIntervalSince(startDate)) * 10
                MeshGradient(width: 3, height: 3, points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    [watchSinInRange(-0.8...(-0.2), offset: 0.439, timeScale: 0.342, t: t), watchSinInRange(0.3...0.7, offset: 3.42, timeScale: 0.984, t: t)],
                    [watchSinInRange(0.1...0.8, offset: 0.239, timeScale: 0.084, t: t), watchSinInRange(0.2...0.8, offset: 5.21, timeScale: 0.242, t: t)],
                    [watchSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.084, t: t), watchSinInRange(0.4...0.8, offset: 0.25, timeScale: 0.642, t: t)],
                    [watchSinInRange(-0.8...0.0, offset: 1.439, timeScale: 0.442, t: t), watchSinInRange(1.4...1.9, offset: 3.42, timeScale: 0.984, t: t)],
                    [watchSinInRange(0.3...0.6, offset: 0.339, timeScale: 0.784, t: t), watchSinInRange(1.0...1.2, offset: 1.22, timeScale: 0.772, t: t)],
                    [watchSinInRange(1.0...1.5, offset: 0.939, timeScale: 0.056, t: t), watchSinInRange(1.3...1.7, offset: 0.47, timeScale: 0.342, t: t)]
                ], colors: [
                    .blue, .red, .orange,
                    .orange, .indigo, .red,
                    .cyan, .purple, .mint
                ])
            }
        } else {
            AngularGradient(
                colors: [.blue, .indigo, .purple, .orange, .mint, .red, .blue],
                center: .center
            )
        }
    }
}

private func watchSinInRange(_ range: ClosedRange<Float>, offset: Float, timeScale: Float, t: Float) -> Float {
    let amplitude = (range.upperBound - range.lowerBound) / 2
    let midPoint = (range.upperBound + range.lowerBound) / 2
    return midPoint + amplitude * sin(timeScale * t + offset)
}
