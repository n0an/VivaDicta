//
//  MainView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.14
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Bindable var appState: AppState
    @State private var showingRecordingSheet = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var isSearchFieldExpanded = false
    
    @Namespace private var recordSheetTransition
    
    var body: some View {
        NavigationStack {
            TranscriptionsContentView(appState: appState, searchText: $searchText)
                .searchable(text: $searchText, placement: .toolbar)
                .minimizedSearch()
            
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Top trailing - Settings button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            
            
                .toolbar {
                    if #available(iOS 26.0, *) {
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                        
                        ToolbarItem(placement: .bottomBar) {
                            
                            Button {
                                  showingRecordingSheet = true
                              } label: {
                                  Image(systemName: "microphone.circle")
                                      .font(.system(size: 24))
                              }
                              .buttonStyle(.glassProminent)
                              .tint(.orange)
                            
                            
                        }
                        .matchedTransitionSource(id: "RecordSheetTransition", in: recordSheetTransition)
                    } else {
                        ToolbarItem(placement: .bottomBar) {
                            Button("") {
                                showingRecordingSheet = true
                            }
                            .buttonStyle(RecordButtonButtonStyle())
                        }
                    }
                }
                .sheet(isPresented: $showingRecordingSheet) {
                    RecordingSheetView(
                        appState: appState,
                        isPresented: $showingRecordingSheet
                    )
                    .navigationTransition(.zoom(sourceID: "RecordSheetTransition", in: recordSheetTransition))
                }
                .navigationDestination(isPresented: $showingSettings) {
                    SettingsView(appState: appState)
                        .navigationBarBackButtonHidden(false)
                }
        }
        .onChange(of: appState.shouldPresentRecordingSheet) { _, newValue in
            if newValue {
                showingRecordingSheet = true
                appState.shouldPresentRecordingSheet = false
            }
        }
        .onChange(of: appState.shouldNavigateToModels) { _, newValue in
            if newValue {
                showingSettings = true
                // The SettingsView should handle navigation to models internally
            }
        }
    }
}

#Preview(traits: .transcriptionsMockData) {
    @State @Previewable var appState = AppState()
    MainView(appState: appState)
}


