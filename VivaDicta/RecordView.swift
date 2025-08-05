//
//  RecordView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI

struct RecordView: View {
    @State var vm = RecordViewModel()
    @State var isSymbolAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            switch vm.recordingState {
            case .idle, .error:
                startCaptureButton
            case .recording:
                stopCaptureButton
            case .transcribing:
                Image(systemName: "brain")
                    .symbolEffect(.bounce.up.byLayer, options: .repeating, value: isSymbolAnimating)
                    .font(.system(size: 128))
                    .onAppear { isSymbolAnimating = true }
                    .onDisappear { isSymbolAnimating = false }
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
    
    var stopCaptureButton: some View {
        Button {
            vm.stopCaptureAudio()
            print("stop")
        } label: {
            Image(systemName: "stop.circle")
                .symbolRenderingMode(.multicolor)
                .tint(.red)
                .font(.system(size: 128))
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
