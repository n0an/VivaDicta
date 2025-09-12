//
//  SettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct SettingsView: View {
    
    
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Modes") {
                    
                    ForEach(AIEnhanceModeType.allCases) { mode in
                        NavigationLink(value: mode) {
                            Text(mode.name)
                                .font(.body)
                        }
                        
                    }
                }
            }
            .navigationDestination(for: AIEnhanceModeType.self) { mode in
                AIModeConfigurationView(mode: mode)
            }
        }
    }
}

#Preview {
    SettingsView()
}
