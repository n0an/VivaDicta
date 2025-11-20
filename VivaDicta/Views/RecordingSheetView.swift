//
//  RecordingSheetView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import SwiftUI
import SwiftData
import SiriWaveView

struct RecordingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    @Bindable var appState: AppState

    private var vm: RecordViewModel {
        appState.recordViewModel
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Mode", selection: $appState.recordViewModel.selectedModeName) {
                    ForEach(vm.availableModes, id: \.id) { mode in
                        Text(mode.name)
                            .tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Cancel button (X)
                
                Button(action: { vm.cancelTranscribe() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(.gray.opacity(0.1), in: .circle)
                        .contentShape(.rect)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                
            }
            
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
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(vm.recordingState == .recording)
        .alert(isPresented: $appState.recordViewModel.isShowingAlert, error: vm.recordError) { recordError in
            switch recordError {
            case .userDenied:
                Button("Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                Button("Cancel", role: .cancel) { }
            default:
                Button("OK") { }
            }
        } message: { recordError in
            Text(recordError.failureReason)
        }
    }

    private func stopRecordingAndDismiss() {
        vm.stopCaptureAudio(modelContext: modelContext)
        // Sheet will automatically dismiss when recordingState changes from .recording
        // This happens via the onChange modifier in MainView
    }
}

#Preview {
    @State @Previewable var appState = AppState()
    RecordingSheetView(appState: appState)
}
