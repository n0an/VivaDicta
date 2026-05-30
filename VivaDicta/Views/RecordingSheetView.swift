//
//  RecordingSheetView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import SwiftUI
import AppGroup
import SwiftData

struct RecordingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(AppState.self) var appState

    @AppStorage(UserDefaultsStorage.Keys.recordingOrbStyle)
    private var orbStyle: RecordingOrbStyle = .particles

    @Query(sort: \TranscriptionTag.sortOrder) private var allTags: [TranscriptionTag]

    @State private var recordingStartDate = Date()
    @State private var isTagSelectorExpanded = false

    private var vm: RecordViewModel {
        appState.recordViewModel
    }

    var body: some View {
        @Bindable var appState = appState

        ZStack(alignment: .center) {
            
            Group {
                switch orbStyle {
                case .particles:
                    ParticleOrbView(audioPower: $appState.recordViewModel.audioPower)
                case .ascii:
                    ASCIIOrbView(audioPower: $appState.recordViewModel.audioPower)
                        .offset(y: 10)
                case .hidden:
                    EmptyView()
                }
            }
            .accessibilityHidden(true)
            
            Text(recordingStartDate, style: .timer)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 70)
            
            VStack(spacing: 12) {
                HStack {
                    VivaModePicker(
                        modes: vm.availableModes,
                        selectedModeName: $appState.aiService.selectedModeName,
                        onSelectionChanged: { HapticManager.selectionChanged() }
                    )
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)

                    Spacer()
                    
                    // Cancel button (X)

                    Button(action: { vm.cancelTranscribe() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 44, height: 44)
                            .recordingSheetButtonBackground(color: nil)
                            .contentShape(.circle)
                    }
                    .accessibilityLabel("Cancel Recording")
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    
                }
                
                Spacer()

                if isTagSelectorExpanded {
                    RecordingTagChipsRow(tags: allTags, selectedTagIds: $appState.recordViewModel.pendingTagIds)
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                HStack {
                    // Tag button - opens the inline tag selector (bottom-left corner)
                    if allTags.isEmpty {
                        Color.clear.frame(width: 44, height: 44)
                    } else {
                        RecordingTagButton(
                            selectedCount: vm.pendingTagIds.count,
                            isExpanded: isTagSelectorExpanded,
                            action: toggleTagSelector
                        )
                    }

                    Spacer()

                    Button {
                        stopRecordingAndDismiss()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .recordingSheetButtonBackground(color: .red)
                    }
                    .accessibilityLabel("Stop Recording")
                    .disabled(vm.recordingState != .recording)

                    Spacer()

                    // Balances the leading tag button so the stop button stays centered
                    Spacer()
                        .frame(width: 44)
                }
                .padding(.horizontal, 16)
                .padding(.bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(orbStyle == .hidden ? 220 : 340)])
        .presentationDragIndicator(.hidden)
        .onAppear { recordingStartDate = Date() }
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

    private func toggleTagSelector() {
        HapticManager.lightImpact()
        withAnimation {
            isTagSelectorExpanded.toggle()
        }
    }

    private func stopRecordingAndDismiss() {
        vm.stopCaptureAudio(modelContext: modelContext)
        // Sheet will automatically dismiss when recordingState changes from .recording
        // This happens via the onChange modifier in MainView
    }
}

// MARK: - Recording Tag Button

/// Bottom-left button that reveals the inline tag selector, with a badge showing
/// how many tags are currently selected for the in-progress recording.
private struct RecordingTagButton: View {
    let selectedCount: Int
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "tag")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isExpanded ? Color.accentColor : .secondary)
                .frame(width: 44, height: 44)
                .recordingSheetButtonBackground(color: nil)
                .contentShape(.circle)
                .overlay(alignment: .topTrailing) {
                    if selectedCount > 0 {
                        Text(selectedCount, format: .number)
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(.red, in: .circle)
                    }
                }
        }
        .accessibilityLabel("Tags")
        .accessibilityValue(selectedCount > 0 ? "\(selectedCount) selected" : "None selected")
    }
}

// MARK: - Recording Sheet Button Background

private struct RecordingSheetButtonBackgroundModifier: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let color {
                content
                    .glassEffect(
                        .regular.tint(color).interactive(),
                        in: .circle
                    )
            } else {
                content
                    .glassEffect(.regular.interactive(), in: .circle)
            }
        } else {
            if let color {
                content
                    .background(color, in: .circle)
            } else {
                content
                    .background(.gray.opacity(0.1), in: .circle)
            }
        }
    }
}

extension View {
    fileprivate func recordingSheetButtonBackground(color: Color?) -> some View {
        modifier(RecordingSheetButtonBackgroundModifier(color: color))
    }
}

#if DEBUG
#Preview {
    RecordingSheetView()
        .environment(AppState())
}
#endif
