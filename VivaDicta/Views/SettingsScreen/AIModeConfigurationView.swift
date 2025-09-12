//
//  AIModeConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct AIModeConfigurationView: View {
    
    @State private var viewModel: AIModeConfigurationViewModel
    
    var mode: AIEnhanceMode
    
    init(mode: AIEnhanceMode) {
        self.mode = mode
        self._viewModel = State(initialValue: AIModeConfigurationViewModel(mode: mode))
    }
    
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
                
                Picker(selection: $viewModel.aiProvider) {
                    Text("None").tag(nil as AIProvider?)
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue.capitalized).tag(provider as AIProvider?)
                    }
                    
                } label: {
                    HStack {
                        Image(systemName: "cpu")
                        Text("AI Provider")
                    }
                }
                .onChange(of: viewModel.aiProvider) { _, newProvider in
                    viewModel.updateProvider(newProvider)
                }
                
                Picker(selection: $viewModel.aiModel) {
                    if let provider = viewModel.aiProvider {
                        ForEach(provider.availableModels, id: \.self) { model in
                            Text(model).tag(model as String?)
                        }
                    }
                    
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("AI Model")
                    }
                }
                .onChange(of: viewModel.aiModel) { _, newModel in
                    viewModel.updateModel(newModel)
                }
                .disabled(viewModel.aiProvider == nil)
            }
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
