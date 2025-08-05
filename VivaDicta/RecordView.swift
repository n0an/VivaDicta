//
//  RecordView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI
import SiriWaveView

struct RecordView: View {
    @State var vm = RecordViewModel()
    @State var isSymbolAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            
            
            Spacer()
            SiriWaveView(power: $vm.audioPower)
                .opacity(vm.siriWaveFormOpacity)
                .frame(height: 256)
                .overlay { overlayView }
            Spacer()
            
            switch vm.recordingState {
            case .recording:
                cancelRecordingButton
                
            case .transcribing:
                cancelButton
                
            default: EmptyView()
            }
            
            if case let .error(error) = vm.recordingState {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }
    
    @ViewBuilder
    var overlayView: some View {
        switch vm.recordingState {
        case .idle, .error:
            startCaptureButton
        case .transcribing:
            Image(systemName: "brain")
                .symbolEffect(.bounce.up.byLayer, options: .repeating, value: isSymbolAnimating)
                .font(.system(size: 128))
                .onAppear { isSymbolAnimating = true }
                .onDisappear { isSymbolAnimating = false }
        default: EmptyView()
        }
    }
    
    var startCaptureButton: some View {
        Button {
            vm.startCaptureAudio()
            print("record")
        } label: {
            Image(systemName: "mic.circle")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 128))
        }
        .buttonStyle(.borderless)
    }
    
    var cancelButton: some View {
        Button(role: .destructive) {
            vm.stopCaptureAudio()
        } label: {
            Image(systemName: "stop.circle.fill")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.red)
                .font(.system(size: 44))
        }
        .buttonStyle(.borderless)

    }
    
    var cancelRecordingButton: some View {
        Button(role: .destructive) {
            vm.stopCaptureAudio()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 44))
        }
        .buttonStyle(.borderless)

    }
    
}

#Preview("Idle") {
    RecordView()
}

#Preview("Recording") {
    let vm = RecordViewModel()
    vm.recordingState = .recording
    vm.audioPower = 0.3
    return RecordView(vm: vm)
}

#Preview("Transcribing") {
    let vm = RecordViewModel()
    vm.recordingState = .transcribing
    return RecordView(vm: vm)
}

#Preview("Error") {
    let vm = RecordViewModel()
    vm.recordingState = .error(RecordError())
    return RecordView(vm: vm)
}
