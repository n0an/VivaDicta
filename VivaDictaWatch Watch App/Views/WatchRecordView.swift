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
        .accessibilityIdentifier("WatchRecordView.mainButton")
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
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 16, weight: .semibold))
        }
        .accessibilityIdentifier("WatchRecordView.modePicker")
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
                          opacity: Double = 1.0) -> some View {
        modifier(GlassEffectColorModifier(
            isInteractive: isInteractive,
            color: color,
            opacity: opacity))
    }
}


struct GlassEffectClearModifier: ViewModifier {
    
    var isInteractive: Bool
    
    func body(content: Content) -> some View {
        if #available(watchOS 26, *){
            content
                .glassEffect(.clear.interactive(isInteractive))
        } else {
            content
                .background {
                    Capsule()
                        .stroke(.gray, lineWidth: 1)
                }
        }
    }
}

extension View {
    func glassEffectClear(isInteractive: Bool = true) -> some View {
        modifier(GlassEffectClearModifier(isInteractive: isInteractive))
    }
}
