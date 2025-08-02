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
    var body: some View {
        let _ = Self._printChanges()
        let _ = print("Executing <TabBarView> body")
        
        TabView(selection: $selectedTab) {
            
            Tab("Record", systemImage: "waveform.circle.fill", value: TabTag.record) {
                Text("Record")
                    .badge { Text(10, format: .number) }
                    
            }
            
            Tab("Notes", systemImage: "text.document", value: TabTag.transcriptions) {
                Text("Notes")
            }
            
            Tab("Models", systemImage: "sparkles", value: TabTag.models) {
                Text("Models")
            }
            
            Tab("Settings", systemImage: "gear", value: TabTag.settings) {
                Text("Models")
            }
        }
        .badgeStyle(.fancy)
        
    }
}

#Preview {
    TabBarView()
}

