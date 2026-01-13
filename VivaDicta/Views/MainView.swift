//
//  MainView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import SwiftUI
import SwiftData
import TipKit
import UniformTypeIdentifiers
import os

struct MainView: View {
    @Environment(AppState.self) var appState
    @Environment(Router.self) var router

    @State private var showingRecordingSheet = false
    @State private var showingSettings = false
    @State private var showingFileImport = false
    @State private var searchText = ""

    @State var rippleEffectTimer: Timer?
    @State var rippleEffectTrigger = false
    @State private var showNoModelAlert = false
    @State private var showFileErrorAlert = false
    @State private var fileErrorMessage = ""

    private let logger = Logger(category: .mainView)

    @Namespace private var sheetTransitions

    @Environment(\.modelContext) private var modelContext
    
    var selectTranscriptionModelTipMainView = SelectTranscriptionModelTipMainView()
        
    var body: some View {
        @Bindable var appState = appState
        @Bindable var router = router

//        let _ = Self._printChanges()
//        let _ = print("Executing <MainView> body")
        
        NavigationStack(path: $router.path) {
            TranscriptionsContentView(searchText: $searchText)
                .searchable(text: $searchText, placement: .toolbar)
                .minimizedSearch()
            
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                HapticManager.lightImpact()
                                showingSettings = true
//                                selectTranscriptionModelTipMainView.invalidate(reason: .actionPerformed)
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                            .popoverTip(selectTranscriptionModelTipMainView) { action in
                                if action.id == "go-to-models" {
                                    showingSettings = true
                                    appState.shouldNavigateToModels = true
                                }
                            }
                        }
                        .matchedTransitionSource(id: "SettingsSheetTransition", in: sheetTransitions)
                    } else {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                HapticManager.lightImpact()
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                            .tint(.primary)
                            .popoverTip(selectTranscriptionModelTipMainView) { action in
                                if action.id == "go-to-models" {
                                    showingSettings = true
                                    appState.shouldNavigateToModels = true
                                }
                            }
                        }
                    }

                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Menu {
                            ForEach(appState.aiService.modes) { mode in
                                Button {
                                    appState.aiService.selectedMode = mode
                                } label: {
                                    if mode.id == appState.aiService.selectedMode.id {
                                        Label(mode.name, systemImage: "checkmark")
                                    } else {
                                        Text(mode.name)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(appState.aiService.selectedMode.name.truncated(to: 16))
                                    .font(.headline)
                                    .bold()
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.fill.tertiary, in: .capsule)
                        }
                        .tint(.primary)
                    }
                }
            
                .toolbar {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                HapticManager.lightImpact()
                                showingFileImport = true
//                                selectTranscriptionModelTipMainView.invalidate(reason: .actionPerformed)
                            } label: {
                                Image(systemName: "waveform.badge.plus")
                            }
//                            .popoverTip(selectTranscriptionModelTipMainView) { action in
//                                if action.id == "open-file-importer" {
//                                    showingSettings = true
//                                    appState.shouldNavigateToModels = true
//                                }
//                            }
                        }
                        .matchedTransitionSource(id: "FileImportSheetTransition", in: sheetTransitions)
                    } else {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                HapticManager.lightImpact()
                                showingFileImport = true
                            } label: {
                                Image(systemName: "waveform.badge.plus")
                            }
                            .tint(.primary)
//                            .popoverTip(selectTranscriptionModelTipMainView) { action in
//                                if action.id == "open-file-importer" {
//                                    showingFileImport = true
//                                    appState.shouldNavigateToModels = true
//                                }
//                            }
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
                        RecordingSheetView()
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
                        RecordingSheetView()
                    }
                }
                .fullScreenCover(isPresented: $showingSettings) {
                    SettingsView()
                        .interactiveDismissDisabled(true)
                        .navigationTransition(.zoom(sourceID: "SettingsSheetTransition", in: sheetTransitions))
                }
                .fileImporter(
                    isPresented: $showingFileImport,
                    allowedContentTypes: [.audio, .mpeg4Audio, .wav, .mp3, .aiff],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result)
                }
                .navigationDestination(for: Transcription.self) { transcription in
                    TranscriptionDetailView(transcription: transcription)
                }
                .alert("No Transcription Model", isPresented: $showNoModelAlert, actions: {
                    Button("Go to Models") {
                        appState.shouldNavigateToModels = true
                    }
                }, message: {
                    Text("To start recording, please download a local model or select a cloud transcription model.")
                })
                .alert("File Error", isPresented: $showFileErrorAlert, actions: {
                    Button("OK", role: .cancel) {}
                }, message: {
                    Text(fileErrorMessage)
                })
                .alert(
                    "AI Safety Guardrail Triggered",
                    isPresented: Binding(
                        get: { appState.recordViewModel?.isShowingAlert == true && appState.recordViewModel?.recordError == .aiGuardrail },
                        set: { if !$0 { appState.recordViewModel?.isShowingAlert = false } }
                    )
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Apple's on-device AI blocked this content due to safety guidelines. Your transcription was saved without AI enhancement. Consider using a cloud AI provider for this type of content.")
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
                HudView(
                    state: appState.recordViewModel?.recordingState ?? .idle,
                    onCancel: {
                        appState.recordViewModel?.cancelProcessing()
                    }
                )
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
        .onChange(of: appState.shouldTranscribeSharedAudio) { _, newValue in
            if newValue {
                // Dismiss any presented screens to return to main view
                showingSettings = false
                showingRecordingSheet = false
                router.popToRoot()

                handleSharedAudioTranscription()
                appState.shouldTranscribeSharedAudio = false
            }
        }
        .sheet(isPresented: $appState.showKeyboardFlowSheet) {
            KeyboardFlowSheet()
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            SelectTranscriptionModelTipMainView.isTranscriptionReady = appState.transcriptionManager.hasAvailableTranscriptionModels
            SelectTranscriptionModelTipSettingsView.isTranscriptionReady = appState.transcriptionManager.hasAvailableTranscriptionModels
        }
        .task {
            // Clean up old audio files (based on user settings)
            // Called here instead of app init to ensure SwiftData is fully initialized
            await AudioCleanupService.shared.performCleanupIfNeeded(modelContext: modelContext)
        }
        .onChange(of: appState.transcriptionManager.hasAvailableTranscriptionModels) { _, newValue in
            SelectTranscriptionModelTipMainView.isTranscriptionReady = newValue
            SelectTranscriptionModelTipSettingsView.isTranscriptionReady = newValue
        }
    }

    private func startRecording() {
        guard let vm = appState.recordViewModel else { return }

        // Check if we have a transcription model selected
        if vm.transcriptionManager.getCurrentTranscriptionModel() == nil {
            // Show alert explaining why recording can't start
            HapticManager.warning()
            showNoModelAlert = true
            return
        }

        // Start recording directly
        vm.startCaptureAudio()
    }

    private func handleFileImport(_ result: Result<[URL], any Error>) {
        guard let vm = appState.recordViewModel else { return }

        // Check if we have a transcription model selected
        if vm.transcriptionManager.getCurrentTranscriptionModel() == nil {
            HapticManager.warning()
            showNoModelAlert = true
            return
        }

        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }

            // Start accessing the security-scoped resource
            guard selectedURL.startAccessingSecurityScopedResource() else {
                logger.logError("Failed to access security-scoped resource: \(selectedURL.lastPathComponent)")
                fileErrorMessage = "Unable to access the selected file. Please try again."
                HapticManager.error()
                showFileErrorAlert = true
                return
            }

            defer {
                selectedURL.stopAccessingSecurityScopedResource()
            }

            // Copy file to app's audio directory with unique name
            let audioDirectory = FileManager.appDirectory(for: .audio)
            let fileExtension = selectedURL.pathExtension.isEmpty ? "m4a" : selectedURL.pathExtension
            let destinationURL = audioDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")

            do {
                try FileManager.default.copyItem(at: selectedURL, to: destinationURL)

                // Start transcription
                vm.transcribingSpeechTask = vm.transcribeSpeechTask(
                    recordURL: destinationURL,
                    modelContext: modelContext
                )
            } catch {
                logger.logError("Failed to copy imported file: \(error.localizedDescription)")
                fileErrorMessage = "Failed to import audio file: \(error.localizedDescription)"
                HapticManager.error()
                showFileErrorAlert = true
            }

        case .failure(let error):
            logger.logError("File import failed: \(error.localizedDescription)")
            fileErrorMessage = "Failed to import file: \(error.localizedDescription)"
            HapticManager.error()
            showFileErrorAlert = true
        }
    }

    private func handleSharedAudioTranscription() {
        guard let vm = appState.recordViewModel else { return }

        // Check if we have a transcription model selected
        if vm.transcriptionManager.getCurrentTranscriptionModel() == nil {
            HapticManager.warning()
            showNoModelAlert = true
            return
        }

        // Get the pending shared audio filename from AppGroupCoordinator
        guard let pendingFileName = AppGroupCoordinator.shared.getAndConsumePendingSharedAudioFileName(),
              let sharedAudioDir = AppGroupCoordinator.shared.sharedAudioDirectory else {
            logger.logError("No pending shared audio file found")
            return
        }

        let sourceURL = sharedAudioDir.appendingPathComponent(pendingFileName)

        // Verify the file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            logger.logError("Shared audio file does not exist: \(pendingFileName)")
            fileErrorMessage = "The shared audio file could not be found."
            HapticManager.error()
            showFileErrorAlert = true
            return
        }

        // Copy file to app's audio directory with unique name
        let audioDirectory = FileManager.appDirectory(for: .audio)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let destinationURL = audioDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            // Clean up the shared file
            try? FileManager.default.removeItem(at: sourceURL)

            // Reload the selected VivaMode from Share Extension before transcription
            appState.aiService.reloadSelectedModeFromExtension()
            // Update TranscriptionManager with the reloaded mode
            appState.transcriptionManager.setCurrentMode(appState.aiService.selectedMode)

            // Apply language override from Share Extension if present
            if let languageOverride = AppGroupCoordinator.shared.getAndConsumePendingLanguageOverride() {
                appState.transcriptionManager.selectedLanguage = languageOverride
            }

            // Start transcription
            vm.transcribingSpeechTask = vm.transcribeSpeechTask(
                recordURL: destinationURL,
                modelContext: modelContext
            )
        } catch {
            logger.logError("Failed to copy shared audio file: \(error.localizedDescription)")
            fileErrorMessage = "Failed to process shared audio: \(error.localizedDescription)"
            HapticManager.error()
            showFileErrorAlert = true
        }
    }
}

#Preview(traits: .transcriptionsMockData) {
    MainView()
        .environment(AppState())
        .environment(Router())
}
