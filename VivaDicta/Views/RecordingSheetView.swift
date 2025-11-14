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
        VStack(spacing: 40) {
            // Drag indicator and spacing
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Spacer(minLength: 20)

            // SiriWaveView for audio visualization
            SiriWaveView(power: $appState.recordViewModel.audioPower)
                .frame(height: 200)
                .padding(.horizontal, 20)

            // Stop button
            Button {
                stopRecordingAndDismiss()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red)
            }
            .disabled(vm.recordingState != .recording)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden) // We use custom drag indicator
        .interactiveDismissDisabled(vm.recordingState == .recording) // Prevent dismissal during recording
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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