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

    @State private var recordingStartDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
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
                .padding(.leading, 16)

                Spacer()

                Button {
                    HapticManager.lightImpact()
                    dictationState.requestCancelRecording()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(.gray.opacity(0.1), in: .circle)
                        .contentShape(.rect)
                }
                .padding(.trailing, 16)
            }

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
                .background(.red, in: .capsule)
            }
        }
        .onAppear {
            recordingStartDate = Date()
        }
    }
}

// MARK: - Preview

#Preview {
    RecordingStateView(
        dictationState: KeyboardDictationState()
    )
}
