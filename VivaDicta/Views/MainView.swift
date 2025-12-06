//
//  MainView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import SwiftUI
import SwiftData
import TipKit

struct MainView: View {
    @Bindable var appState: AppState
    @State private var showingRecordingSheet = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    
    @State var rippleEffectTimer: Timer?
    @State var rippleEffectTrigger = false

    @Namespace private var sheetTransitions

    @Environment(\.modelContext) private var modelContext
    
    var selectTranscriptionModelTipMainView = SelectTranscriptionModelTipMainView()
    
    var body: some View {
//        let _ = Self._printChanges()
//        let _ = print("Executing <MainView> body")
        
        NavigationStack(path: $navigationPath) {
            TranscriptionsContentView(appState: appState, searchText: $searchText)
                .searchable(text: $searchText, placement: .toolbar)
                .minimizedSearch()
            
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSettings = true
//                                selectTranscriptionModelTipMainView.invalidate(reason: .actionPerformed)
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                            .popoverTip(selectTranscriptionModelTipMainView)
                        }
                        .matchedTransitionSource(id: "SettingsSheetTransition", in: sheetTransitions)
                    } else {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                            .tint(.primary)
                        }
                    }

                }
            
                .toolbar {
                    if #available(iOS 26.0, *) {
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                        
                        ToolbarItem(placement: .bottomBar) {

                            Button {
                                startRecording()
                            } label: {
                                Image(systemName: "microphone.circle")
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.orange)
                        }
                        .matchedTransitionSource(id: "RecordSheetTransition", in: sheetTransitions)
                    } else {
                        ToolbarItem(placement: .bottomBar) {
                            Button("") {
                                startRecording()
                            }
                            .buttonStyle(RecordButtonButtonStyle())
                        }
                    }
                }
                .sheet(isPresented: $showingRecordingSheet) {
                    if #available(iOS 26.0, *) {
                        RecordingSheetView(appState: appState)
                        // TODO: Move inside RecordingSheetView
                        
//                            .background {
//                                                                
//                                AnimatedMeshGradient()
//                                    .onAppear {
//                                        rippleEffectTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { _ in
//                                            Task { @MainActor in
//                                                rippleEffectTrigger.toggle()
//                                            }
//                                        })
//                                        rippleEffectTimer?.fire()
//                                    }
//                                    .onDisappear {
//                                        rippleEffectTimer?.invalidate()
//                                        rippleEffectTimer = nil
//                                    }
//                                    .mask(
//                                        ContainerRelativeShape()
//                                            .stroke(lineWidth: 8)
//                                            .blur(radius: 22)
//                                    )
//                                    .ignoresSafeArea()
//                                    .modifier(RippleEffect(at: .init(x: 100, y: 100), trigger: rippleEffectTrigger))
//
//                            }
                            
                            .scrollContentBackground(.hidden)
                            .navigationTransition(.zoom(sourceID: "RecordSheetTransition", in: sheetTransitions))
                    } else {
                        RecordingSheetView(appState: appState)
                    }
                }
                .fullScreenCover(isPresented: $showingSettings) {
                    SettingsView(appState: appState)
                        .interactiveDismissDisabled(true)
                        .navigationTransition(.zoom(sourceID: "SettingsSheetTransition", in: sheetTransitions))
                }
                .navigationDestination(for: Transcription.self) { transcription in
                    TranscriptionDetailView(transcription: transcription, appState: appState)
                }
        }
        .overlay {
            if appState.recordViewModel?.recordingState == .recording ||
                appState.recordViewModel?.recordingState == .transcribing ||
                appState.recordViewModel?.recordingState == .enhancing {
                GeometryReader { geometry in
                    AnimatedMeshGradient()
                        .onAppear {
                            rippleEffectTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { _ in
                                Task { @MainActor in
                                    if appState.recordViewModel?.recordingState == .transcribing ||
                                        appState.recordViewModel?.recordingState == .enhancing {
                                        rippleEffectTrigger.toggle()
                                    }
                                }
                            })
                            if appState.recordViewModel?.recordingState == .transcribing ||
                                appState.recordViewModel?.recordingState == .enhancing {
                                rippleEffectTimer?.fire()
                            }
                        }
                        .onDisappear {
                            rippleEffectTimer?.invalidate()
                            rippleEffectTimer = nil
                        }
                        .mask(
                            RoundedRectangle(cornerRadius: 44, style: .continuous)
                                .stroke(lineWidth: 44)
                                .blur(radius: 22)
                        )
                        .ignoresSafeArea()
                        .modifier(RippleEffect(at: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2), trigger: rippleEffectTrigger))
                }
            }
        }
        .overlay {
            
            if appState.recordViewModel?.recordingState == .transcribing ||
                appState.recordViewModel?.recordingState == .enhancing {
                HudView(state: appState.recordViewModel?.recordingState ?? .idle)
            }
            
        }
        .animation(.default, value: appState.recordViewModel?.recordingState)
        .onChange(of: appState.recordViewModel?.recordingState) { _, newState in
            // Show sheet only during active recording, not during transcribing or enhancing
            showingRecordingSheet = (newState == .recording)
        }
        .onChange(of: appState.shouldStartRecording) { _, newValue in
            if newValue {
                startRecording()
                appState.shouldStartRecording = false
            }
        }
        .onChange(of: appState.shouldNavigateToModels) { _, newValue in
            if newValue {
                showingSettings = true
                // The SettingsView should handle navigation to models internally
            }
        }
        .onChange(of: appState.selectedTranscriptionID) { _, newID in
            if let transcriptionID = newID {
                // Find the transcription with the matching ID
                let descriptor = FetchDescriptor<Transcription>(
                    predicate: #Predicate { transcription in
                        transcription.id == transcriptionID
                    }
                )

                if let transcription = try? modelContext.fetch(descriptor).first {
                    // Navigate to the transcription detail view
                    navigationPath.append(transcription)
                    // Reset the selectedTranscriptionID
                    appState.selectedTranscriptionID = nil
                }
            }
        }
        .sheet(isPresented: $appState.showKeyboardFlowSheet) {
            KeyboardFlowSheet(appState: appState)
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.hidden)
        }
    }

    private func startRecording() {
        guard let vm = appState.recordViewModel else { return }

        // Check if we have a transcription model selected
        if vm.transcriptionManager.getCurrentTranscriptionModel() == nil {
            // Navigate to settings/models
            appState.shouldNavigateToModels = true
            return
        }

        // Start recording directly
        vm.startCaptureAudio()
    }
}

#Preview(traits: .transcriptionsMockData) {
    @State @Previewable var appState = AppState()
    MainView(appState: appState)
}
