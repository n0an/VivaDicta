//
//  MainView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme

    @Bindable var appState: AppState
    @State private var showingRecordingSheet = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    @Namespace private var sheetTransitions

    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
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
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
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
                            .scrollContentBackground(.hidden)
                            .navigationTransition(.zoom(sourceID: "RecordSheetTransition", in: sheetTransitions))
                    } else {
                        RecordingSheetView(appState: appState)
                    }
                }
                .fullScreenCover(isPresented: $showingSettings) {
                    NavigationStack {
                        SettingsView(appState: appState)
                            .navigationTitle("Settings")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {

                                if #available(iOS 26.0, *) {
                                    ToolbarItem(placement: .topBarLeading) {
                                        Button("Close", systemImage: "xmark") {
                                            showingSettings = false
                                        }
                                    }
                                } else {
                                    ToolbarItem(placement: .topBarLeading) {
                                        Button("Close") {
                                            showingSettings = false
                                        }
                                    }
                                }
                            }
                    }

                    .interactiveDismissDisabled(true)
                    .navigationTransition(.zoom(sourceID: "SettingsSheetTransition", in: sheetTransitions))
                }
                .navigationDestination(for: Transcription.self) { transcription in
                    TranscriptionDetailView(transcription: transcription)
                }
        }
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


