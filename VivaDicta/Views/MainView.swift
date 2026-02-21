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
    @Query private var transcriptions: [Transcription]

    @State private var showingRecordingSheet = false
    @State private var showingSettings = false
    @State private var showingFileImport = false
    @State private var searchText = ""

    // Selection mode state
    @State private var isSelectionMode = false
    @State private var selectedTranscriptionIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    @State var rippleEffectTimer: Timer?
    @State var rippleEffectTrigger = false
    @State private var showNoModelAlert = false
    @State private var showFileErrorAlert = false
    @State private var fileErrorMessage = ""
    @State private var recordButtonBounceTrigger = 0

    private let logger = Logger(category: .mainView)

    @Namespace private var sheetTransitions

    @Environment(\.modelContext) private var modelContext
    
    var selectTranscriptionModelTipMainView = SelectTranscriptionModelTipMainView()
        
    var body: some View {
        @Bindable var appState = appState
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            mainContentView
        }
        .overlay { recordingOverlay }
        .overlay { hudOverlay }
        .animation(.default, value: appState.recordViewModel?.recordingState)
        .onChange(of: appState.recordViewModel?.recordingState) { _, newState in
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
            }
        }
        .onChange(of: appState.shouldTranscribeSharedAudio) { _, newValue in
            if newValue {
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
        .onAppear { handleOnAppear() }
        .task {
            await AudioCleanupService.shared.performCleanupIfNeeded(modelContext: modelContext)
        }
        .onChange(of: appState.transcriptionManager.hasAvailableTranscriptionModels) { _, newValue in
            SelectTranscriptionModelTipMainView.isTranscriptionReady = newValue
            SelectTranscriptionModelTipSettingsView.isTranscriptionReady = newValue
        }
    }

    // MARK: - Main Content View

    @ViewBuilder
    private var mainContentView: some View {
        TranscriptionsContentView(
            searchText: $searchText,
            isSelectionMode: $isSelectionMode,
            selectedTranscriptionIDs: $selectedTranscriptionIDs
        )
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search notes")
        .minimizedSearch()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { trailingToolbarContent }
        .toolbar { principalToolbarContent }
        .toolbar { leadingToolbarContent }
        .toolbar { bottomToolbarContent }
        .sheet(isPresented: $showingRecordingSheet) { recordingSheetContent }
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
        .alert("No Transcription Model", isPresented: $showNoModelAlert) {
            Button("Go to Models") {
                appState.shouldNavigateToModels = true
            }
        } message: {
            Text("To start recording, please download a local model or select a cloud transcription model.")
        }
        .alert("File Error", isPresented: $showFileErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fileErrorMessage)
        }
        .alert("AI Safety Guardrail Triggered", isPresented: aiGuardrailAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple's on-device AI blocked this content due to safety guidelines. Your transcription was saved without AI processing. Consider using a cloud AI provider for this type of content.")
        }
        .alert(deleteAlertTitle, isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedTranscriptions()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var deleteAlertTitle: String {
        let count = selectedTranscriptionIDs.count
        return "Delete \(count) \(count == 1 ? "Note" : "Notes")?"
    }

    private var aiGuardrailAlertBinding: Binding<Bool> {
        Binding(
            get: { appState.recordViewModel?.isShowingAlert == true && appState.recordViewModel?.recordError == .aiGuardrail },
            set: { if !$0 { appState.recordViewModel?.isShowingAlert = false } }
        )
    }

    @ViewBuilder
    private var recordingSheetContent: some View {
        if #available(iOS 26.0, *) {
            RecordingSheetView()
                .scrollContentBackground(.hidden)
                .navigationTransition(.zoom(sourceID: "RecordSheetTransition", in: sheetTransitions))
        } else {
            RecordingSheetView()
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private var recordingOverlay: some View {
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

    @ViewBuilder
    private var hudOverlay: some View {
        if appState.recordViewModel?.recordingState == .transcribing ||
            appState.recordViewModel?.recordingState == .enhancing {
            HudView(
                state: appState.recordViewModel?.recordingState ?? .idle,
                onCancel: {
                    appState.recordViewModel?.cancelProcessing()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleOnAppear() {
        SelectTranscriptionModelTipMainView.isTranscriptionReady = appState.transcriptionManager.hasAvailableTranscriptionModels
        SelectTranscriptionModelTipSettingsView.isTranscriptionReady = appState.transcriptionManager.hasAvailableTranscriptionModels

        // Trigger record button bounce animation on app start (first 10 launches only)
        if recordButtonBounceTrigger == 0 && AppLaunchTracker.isWithinFirstLaunches(10) {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                recordButtonBounceTrigger += 1
            }
        }

        // Request app rating on app start (with delay to not be jarring)
        Task {
            try? await Task.sleep(for: .seconds(2))
            let count = transcriptions.count
            RateAppManager.requestReviewOnAppStartIfAppropriate(transcriptionCount: count)
        }
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private var trailingToolbarContent: some ToolbarContent {
        if isSelectionMode {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    HapticManager.lightImpact()
                    exitSelectionMode()
                }
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.lightImpact()
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
                .popoverTip(selectTranscriptionModelTipMainView) { action in
                    if action.id == "go-to-models" {
                        showingSettings = true
                        appState.shouldNavigateToModels = true
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var principalToolbarContent: some ToolbarContent {
        if isSelectionMode {
            ToolbarItem(placement: .principal) {
                if !selectedTranscriptionIDs.isEmpty {
                    Text("^[\(selectedTranscriptionIDs.count) Note](inflect: true) selected")
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            ToolbarItem(placement: .principal) {
                VivaModePicker(
                    modes: appState.aiService.modes,
                    selectedModeName: Binding(
                        get: { appState.aiService.selectedModeName },
                        set: { appState.aiService.selectedModeName = $0 }
                    )
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var leadingToolbarContent: some ToolbarContent {
        if isSelectionMode {
            ToolbarItem(placement: .topBarLeading) {
                Button(allDisplayedSelected ? "Deselect All" : "Select All") {
                    HapticManager.lightImpact()
                    toggleSelectAll()
                }
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticManager.lightImpact()
                    showingFileImport = true
                } label: {
                    Image(systemName: "waveform.badge.plus")
                }
                .accessibilityLabel("Import Audio File")
            }

            if #available(iOS 26.0, *) {
                if !transcriptions.isEmpty {
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                }
            }

            if !transcriptions.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.lightImpact()
                        enterSelectionMode()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel("Select Notes")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var bottomToolbarContent: some ToolbarContent {
        if isSelectionMode {
            ToolbarItem(placement: .bottomBar) {
                Spacer()
            }
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    HapticManager.warning()
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
                .disabled(selectedTranscriptionIDs.isEmpty)
            }
        } else {
            if #available(iOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        startRecording()
                    } label: {
                        Image(systemName: "microphone.circle")
                            .font(.system(size: 24))
                            .symbolEffect(.bounce.up.byLayer, options: .repeat(2), value: recordButtonBounceTrigger)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.orange)
                    .accessibilityLabel("Start Recording")
                }
                .matchedTransitionSource(id: "RecordSheetTransition", in: sheetTransitions)
            } else {
                ToolbarItem(placement: .bottomBar) {
                    Button("") {
                        startRecording()
                    }
                    .buttonStyle(RecordButtonButtonStyle(bounceTrigger: recordButtonBounceTrigger))
                    .accessibilityLabel("Start Recording")
                }
            }
        }
    }

    // MARK: - Selection Mode

    private var allDisplayedSelected: Bool {
        !transcriptions.isEmpty && selectedTranscriptionIDs.count == transcriptions.count
    }

    private func enterSelectionMode() {
        isSelectionMode = true
        selectedTranscriptionIDs = []
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedTranscriptionIDs = []
    }

    private func toggleSelectAll() {
        if allDisplayedSelected {
            selectedTranscriptionIDs = []
        } else {
            selectedTranscriptionIDs = Set(transcriptions.map(\.id))
        }
    }

    private func deleteSelectedTranscriptions() {
        HapticManager.heavyImpact()

        for transcription in transcriptions where selectedTranscriptionIDs.contains(transcription.id) {
            let transcriptionID = transcription.id

            // Delete audio file if exists
            if let audioFileName = transcription.audioFileName {
                let audioURL = FileManager.appDirectory(for: .audio).appendingPathComponent(audioFileName)
                try? FileManager.default.removeItem(at: audioURL)
            }

            modelContext.delete(transcription)

            // Remove from Spotlight index
            Task {
                await appState.removeTranscriptionFromSpotlight(transcriptionID)
            }
        }

        do {
            try modelContext.save()
        } catch {
            logger.logError("Failed to save after bulk deletion: \(error.localizedDescription)")
        }

        exitSelectionMode()
    }

    // MARK: - Recording

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

#if DEBUG || QA
#Preview(traits: .transcriptionsMockData) {
    MainView()
        .environment(AppState())
        .environment(Router())
}
#endif
