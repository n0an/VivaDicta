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
        VStack {
            overlayView
        }
    }
    
    @ViewBuilder
    var overlayView: some View {
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
    }
    
    var startCaptureButton: some View {
        Button {
            vm.startCaptureAudio()
            print("record")
        } label: {
            Image(systemName: "mic.circle")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 128))
        }.buttonStyle(.borderless)
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
        }.buttonStyle(.borderless)
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
    vm.recordingState = .error("An error has occured")
    return RecordView(vm: vm)
}
