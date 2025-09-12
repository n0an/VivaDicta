//
//  AIModeConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct AIModeConfigurationView: View {
    
    @State var aiProvider: AIProvider = .openAI
    @State var aiModel: String = ""
    
    var aiModels: [String] = []
    
    var mode: AIEnhanceMode
    
    var body: some View {
        Form {
            Section("Name") {
                Text(mode.name)
            }
            
            Section("Prompt") {
                Text(mode.prompt)
                    .lineLimit(3)
            }
            
            Section("AI Enhance") {
                
                Picker(selection: $aiProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue.capitalized)
                    }
                    
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                        Text("AI Provider")
                    }
                }
                
                Picker(selection: $aiModel) {
                    ForEach(aiProvider.availableModels, id: \.self) { model in
                        Text(model)
                    }
                    
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("AI Model")
                    }
                }
            }
        }
        .task {
            
            aiModel = aiProvider.defaultModel
        }
        
    }
}

struct AIProviderDetails: View {
    
    var body: some View {
        
    }
}

#Preview {
    AIModeConfigurationView(mode: AIEnhanceMode.predefinedModes[0])
}
