//
//  RecordingStateView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import SwiftUI
import KeyboardKit

struct RecordingStateView: View {

    @Bindable var dictationState: KeyboardDictationState
    let onBackspace: () -> Void
    let onDeleteWord: () -> Void
    let onNewline: () -> Void
    let onSpace: () -> Void

    @State private var recordingStartDate = Date()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    VivaModePicker(
                        modes: dictationState.vivaModeManager.availableVivaModes,
                        selectedModeName: Binding(
                            get: { dictationState.vivaModeManager.selectedVivaMode.name },
                            set: { newName in
                                HapticManager.selectionChanged()
                                if let mode = dictationState.vivaModeManager.availableVivaModes.first(where: { $0.name == newName }) {
                                    dictationState.vivaModeManager.selectedVivaMode = mode
                                }
                            }
                        )
                    )

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        utilityButton(icon: "space", color: .blue, action: onSpace)
                            .shadow(color: .black.opacity(0.2), radius: 6)
                        utilityButton(icon: "return", color: .blue, action: onNewline)
                            .shadow(color: .black.opacity(0.2), radius: 6)
                        utilityButton(icon: "delete.backward", color: .red, action: onBackspace, longHoldAction: onDeleteWord)
                            .shadow(color: .black.opacity(0.2), radius: 6)
                    }
                }
                .padding(.horizontal, 16)

                Text(recordingStartDate, style: .timer)
                    .font(.system(size: 64, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .padding(.bottom, 40)

                Button(action: {
                    HapticManager.mediumImpact()
                    dictationState.requestStopRecording()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Stop")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .glassCapsule(tint: .red, fallback: Color.red)
                }
            }

            cancelButton
                .padding(.leading, 16)
                .padding(.bottom, 8)
        }
        .onAppear {
            recordingStartDate = Date()
        }
    }

    @ViewBuilder
    private func utilityButton(
        icon: String,
        color: Color,
        action: @escaping () -> Void,
        longHoldAction: (() -> Void)? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            RepeatableButton(action: action, longHoldAction: longHoldAction) {
                utilityButtonLabel(icon: icon)
                    .frame(width: 36, height: 20)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .glassEffect(.regular.tint(color.opacity(0.3)).interactive())
        } else {
            RepeatableButton(action: action, longHoldAction: longHoldAction) {
                utilityButtonLabel(icon: icon)
                    .frame(width: 40, height: 24)
                    .background(color.opacity(0.5), in: .capsule(style: .continuous))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
    }

    private func utilityButtonLabel(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.primary)
            .contentShape(.rect)
    }

    private var cancelButton: some View {
        Button {
            HapticManager.lightImpact()
            dictationState.requestCancelRecording()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 44, height: 44)
                .glassDismissCircle()
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    RecordingStateView(
        dictationState: KeyboardDictationState(),
        onBackspace: {},
        onDeleteWord: {},
        onNewline: {},
        onSpace: {}
    )
}
