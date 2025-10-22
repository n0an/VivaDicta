//
//  RecordingStateView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.03
//

import SwiftUI
import KeyboardKit
import SiriWaveView

struct RecordingStateView: View {

    @State var isSymbolAnimating = false

    @Bindable var dictationState: KeyboardDictationState
    
    
    var body: some View {
        
        VStack(spacing: 0) {
            // Top Bar with Cancel Button
            HStack {
                Spacer()
                
                // Cancel button (X)
                Button(action: { dictationState.requestCancelRecording() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(.gray.opacity(0.1), in: .circle)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            Spacer()
            
            // Flow Mode Picker
            VStack(spacing: 20) {
                Picker("Flow Mode", selection: $dictationState.flowModeManager.selectedFlowMode) {
                    ForEach(dictationState.flowModeManager.availableFlowModes, id: \.id) { mode in
                        Text(mode.name).tag(mode)
                    }
                }
                .tint(.primary)
                .pickerStyle(.menu)
                .frame(minWidth: 120)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Recording indicator with audio level visualization
                VStack(spacing: 12) {
                    Image(systemName: "microphone.circle.fill")
                        .foregroundStyle(Color.green)
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), value: isSymbolAnimating)
                        .font(.system(size: 30))
                    .onAppear { isSymbolAnimating = true }
                    .onDisappear { isSymbolAnimating = false }
                    
                    SiriWaveView(power: .constant(dictationState.currentAudioLevel))
                        .frame(height: 80)
                }
                .padding(.vertical, 20)
            }
            
            Spacer()
            
            // Stop Button
            Button(action: { dictationState.requestStopRecording() }) {
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
                .background(
                    Capsule()
                        .fill(Color.red)
                )
            }
            .padding(.bottom, 30)
        }
        
    }
}

// MARK: - Preview
//
#Preview {
    RecordingStateView(
        dictationState: KeyboardDictationState()
    )
}
