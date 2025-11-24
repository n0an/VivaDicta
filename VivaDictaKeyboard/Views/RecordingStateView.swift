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
    
    @State private var maskTimer: Float = 0.0

    @State var isSymbolAnimating = false

    @Bindable var dictationState: KeyboardDictationState
    
    @State var timer: Timer?

    private var rectangleSpeed: Float {
        
        switch dictationState.uiState {
        case .recording:
            0.03
        case .processing:
            0.03
        default:
            0
        
        }
        
//        switch state {
//        case .none: return 0
//        case .thinking: return 0.03
//        }
    }
    
    
    
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Flow Mode", selection: $dictationState.flowModeManager.selectedFlowMode) {
                    ForEach(dictationState.flowModeManager.availableFlowModes, id: \.id) { mode in
                        Text(mode.name).tag(mode)
                    }
                }
                .tint(.primary)
                .pickerStyle(.menu)
                
                Spacer()
                
                // Cancel button (X)
                Button(action: { dictationState.requestCancelRecording() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(.gray.opacity(0.1), in: .circle)
                        .contentShape(.rect)
                }
                .padding(.trailing, 8)
            }
            
            SiriWaveView(power: .constant(dictationState.currentAudioLevel))
                .frame(height: 140)
            
            // Stop Button
            Button(action: dictationState.requestStopRecording) {
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
        .overlay {
            if dictationState.uiState == .recording || dictationState.uiState == .processing {
                AnimatedMeshGradient()
                    .mask(
                        AnimatedRectangle(size: .init(width: 80, height: 80), cornerRadius: 20, t: CGFloat(maskTimer))
                    )
                    .frame(width: 80, height: 80)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                Task { @MainActor in
                    maskTimer += rectangleSpeed
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
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
