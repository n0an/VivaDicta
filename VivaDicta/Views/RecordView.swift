//
//  RecordView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI
import SiriWaveView

// TODO: Old file , not used, kept for reference for animations for transcribe and enhance states

struct RecordView: View {
    @Environment(\.modelContext) var modelContext
    @Bindable var appState: AppState
    @State var isSymbolAnimating = false

    private var vm: RecordViewModel {
        appState.recordViewModel
    }

    var body: some View {
        if vm.transcriptionManager.getCurrentTranscriptionModel() != nil {
            modelSelectedView

        } else {
            Button {
                vm.appState?.shouldNavigateToModels = true
            } label: {
                Text("Select transcription model")
            }
        }
    }

    init(appState: AppState) {
        self.appState = appState
    }
    
    var modelSelectedView: some View {
        VStack(spacing: 16) {
            modePicker
            whisperKitPerformanceInfo
            Spacer()
            SiriWaveView(power: $appState.recordViewModel.audioPower)
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
        .alert(isPresented: $appState.recordViewModel.isShowingAlert, error: vm.recordError) { recordError in
            
            switch recordError {
            case .userDenied:
                Button("Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                Button("Cancel", role: .cancel) { }
            default:
                EmptyView()
            }
            
        } message: { recordError in
            Text(recordError.failureReason)
        }
    }
    
    @ViewBuilder
    var overlayView: some View {
        switch vm.recordingState {
        case .idle, .error:
            startCaptureButton
        case .transcribing:
            VStack(spacing: 12) {
                Image(systemName: "pencil.and.scribble")
                    .symbolEffect(.bounce.byLayer, options: .repeat(.periodic(delay: 0.3)), value: isSymbolAnimating)
                    
                    .font(.system(size: 80))
                    .onAppear { isSymbolAnimating = true }
                    .onDisappear { isSymbolAnimating = false }

                Text("Transcribing...")
            }
        case .enhancing:
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), value: isSymbolAnimating)
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .onAppear { isSymbolAnimating = true }
                    .onDisappear { isSymbolAnimating = false }

                Text("Enhancing with AI...")
            }
        default: EmptyView()
        }
    }
    
    var startCaptureButton: some View {
        Button {
            vm.startCaptureAudio()
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

    var modePicker: some View {
        HStack {
            Spacer()

            Picker("Mode", selection: $appState.recordViewModel.selectedModeName) {
                ForEach(vm.availableModes, id: \.name) { mode in
                    Text(mode.name)
                        .tag(mode.name)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    @ViewBuilder
    var whisperKitPerformanceInfo: some View {
        // Only show if current model is WhisperKit and we have prewarm time
        if let currentModel = vm.transcriptionManager.getCurrentTranscriptionModel(),
           currentModel.provider == .whisperKit,
           vm.transcriptionManager.whisperKitPrewarmDuration > 0 {
            VStack(spacing: 4) {
                Text("WhisperKit Performance")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Prewarm: \(vm.transcriptionManager.whisperKitPrewarmDuration.formatted(.number.precision(.fractionLength(2))))s")
                        .font(.caption2)
                        .foregroundStyle(.green)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("Load: \(vm.transcriptionManager.whisperKitLoadDuration.formatted(.number.precision(.fractionLength(2))))s")
                        .font(.caption2)
                        .foregroundStyle(.blue)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("Total: \(vm.transcriptionManager.whisperKitTotalInitDuration.formatted(.number.precision(.fractionLength(2))))s")
                        .font(.caption2)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
            }
            .padding(.horizontal)
        }
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
