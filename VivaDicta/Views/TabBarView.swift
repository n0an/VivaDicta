//
//  TabBarView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import SwiftUI

struct TabBarView: View {
    enum TabTag {
        case record
        case transcriptions
        case models
        case settings
    }
    
    @State var selectedTab: TabTag = .record
    @State var whisperState = WhisperState()
    
    var body: some View {
        let _ = Self._printChanges()
        let _ = print("Executing <TabBarView> body")
        
        TabView(selection: $selectedTab) {
            
            Tab("Record", systemImage: "waveform.circle.fill", value: TabTag.record) {
                RecordView(selectedTab: $selectedTab)
                    
            }
            
            Tab("Notes", systemImage: "text.document", value: TabTag.transcriptions) {
                TranscriptionsView()
                    
            }
            
            Tab("Models", systemImage: "sparkles", value: TabTag.models) {
                ModelsView(whisperState: whisperState)
            }
            .badge(whisperState.canTranscribe ? 1 : 0)
            
            Tab("Settings", systemImage: "gear", value: TabTag.settings) {
                Text("Models")
            }
        }
        .badgeStyle(.fancy)
        
    }
}

#Preview(traits: .transcriptionsMockData) {
    TabBarView()
}
