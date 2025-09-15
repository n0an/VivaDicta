//
//  TabBarView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import SwiftUI
import TipKit

struct TabBarView: View {
    @State var appState = AppState()
    
    var body: some View {
        let _ = Self._printChanges()
        let _ = print("Executing <TabBarView> body")
        
        TabView(selection: $appState.selectedTab) {
            
            Tab("Record", systemImage: "waveform.circle.fill", value: TabTag.record) {
                RecordView(appState: appState)
            }
            
            Tab("Notes", systemImage: "text.document", value: TabTag.transcriptions) {
                TranscriptionsView(appState: appState)
            }
            
            Tab("Models", systemImage: "sparkles", value: TabTag.models) {
                ModelsScreen(appState: appState)
            }
            
            Tab("Settings", systemImage: "gear", value: TabTag.settings) {
                SettingsView(appState: appState)
            }
        }
        .task {
//            try? Tips.resetDatastore()
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)])
        }
        .badgeStyle(.fancy)
        
    }
}

#Preview(traits: .transcriptionsMockData) {
    TabBarView()
}
