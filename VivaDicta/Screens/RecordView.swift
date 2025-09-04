//
//  RecordView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI
import SiriWaveView

struct RecordView: View {
    @Environment(\.modelContext) var modelContext
    @State var vm = RecordViewModel()
    @State var isSymbolAnimating = false
    
    var appState: AppState
    
    var body: some View {
        if appState.currentTranscriptionModel != nil {
            modelSelectedView
            
        } else {
            Button {
                print("send to models screen")
                appState.selectedTab = .models
            } label: {
                Text("Select transcription model")
            }
        }
    }
    
    init(appState: AppState) {
        self._vm = State(wrappedValue: RecordViewModel(appState: appState))
        self.appState = appState
    }
    
    var modelSelectedView: some View {
        VStack(spacing: 16) {
            Spacer()
            SiriWaveView(power: $vm.audioPower)
                .opacity(vm.siriWaveFormOpacity)
                .frame(height: 256)
                .overlay { overlayView }
            Spacer()
            
            switch vm.recordingState {
            case .recording:
                stopRecordingButton
                
            case .transcribing:
                cancelTranscribingButton
                
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
    
    var stopRecordingButton: some View {
        Button(role: .destructive) {
            vm.stopCaptureAudio(modelContext: modelContext)
        } label: {
            Image(systemName: "stop.circle.fill")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.red)
                .font(.system(size: 44))
        }
        .buttonStyle(.borderless)

    }
    
    var cancelTranscribingButton: some View {
        Button(role: .destructive) {
            vm.cancelTranscribe()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 44))
        }
        .buttonStyle(.borderless)
    }
}

#Preview("Idle") {
    @State @Previewable var appState = AppState()
    RecordView(appState: appState)
}

//#Preview("Recording") {
//    @State @Previewable var appState = AppState()
//    let vm = RecordViewModel(transcriptionService: appState.transcriptionService)
//    vm.recordingState = .recording
//    vm.audioPower = 0.3
//    return RecordView(vm: vm, appState: appState)
//}
//
//#Preview("Transcribing") {
//    @State @Previewable var appState = AppState()
//    let vm = RecordViewModel(transcriptionService: appState.transcriptionService)
//    vm.recordingState = .transcribing
//    return RecordView(vm: vm, appState: appState)
//}
//
//#Preview("Error") {
//    @State @Previewable var appState = AppState()
//    let vm = RecordViewModel(transcriptionService: appState.transcriptionService)
//    vm.recordingState = .error(RecordError.avInitError)
//    return RecordView(vm: vm, appState: appState)
//}
