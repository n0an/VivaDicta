//
//  RecordingSheetView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import SwiftUI
import SiriWaveView

struct RecordingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    @Bindable var appState: AppState
    @Binding var isPresented: Bool
    @State private var hasStartedRecording = false

    private var vm: RecordViewModel {
        appState.recordViewModel
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            SiriWaveView(power: $appState.recordViewModel.audioPower)
                .frame(height: 80)
                .padding(.horizontal, 20)
            Spacer()
            
            Button {
                stopRecordingAndDismiss()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
            }
            .disabled(vm.recordingState != .recording)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(vm.recordingState == .recording)
        .onAppear {
            startRecordingImmediately()
        }
        .onChange(of: vm.recordingState) { oldState, newState in
            handleRecordingStateChange(oldState: oldState, newState: newState)
        }
        .alert(isPresented: $appState.recordViewModel.isShowingAlert, error: vm.recordError) { recordError in
            switch recordError {
            case .userDenied:
                Button("Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    isPresented = false
                }
                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
            default:
                Button("OK") {
                    isPresented = false
                }
            }
        } message: { recordError in
            Text(recordError.failureReason)
        }
    }

    private func startRecordingImmediately() {
        guard !hasStartedRecording else { return }

        // Check if we have a transcription model selected
        if vm.transcriptionManager.getCurrentTranscriptionModel() == nil {
            // Dismiss sheet and navigate to settings/models
            isPresented = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                appState.shouldNavigateToModels = true
            }
            return
        }

        hasStartedRecording = true
        vm.startCaptureAudio()
    }

    private func stopRecordingAndDismiss() {
        vm.stopCaptureAudio(modelContext: modelContext)
    }

    private func handleRecordingStateChange(oldState: RecordingState, newState: RecordingState) {
        // Auto-dismiss when transcription/enhancement completes and returns to idle
        // But only if we actually started recording (not on initial idle state)
        if hasStartedRecording {
            switch newState {
            case .idle:
                // Recording → Transcribing → Idle means success
                // Give a small delay for user to see the completion
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    isPresented = false
                    hasStartedRecording = false
                }
            case .error:
                // On error, keep sheet open but allow dismissal
                // User can manually dismiss after seeing the error
                break
            default:
                break
            }
        }
    }
}

#Preview {
    @State @Previewable var appState = AppState()
    @State @Previewable var isPresented = true
    RecordingSheetView(appState: appState, isPresented: $isPresented)
}
