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
    let aiService: AIService
    
    init(mode: AIEnhanceMode, aiService: AIService) {
        self.mode = mode
        self.aiService = aiService
        self._viewModel = State(initialValue: AIModeConfigurationViewModel(mode: mode, aiService: aiService))
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
                
                if let provider = viewModel.aiProvider {
                    let hasKey = viewModel.hasAPIKey(for: provider)
                    if hasKey {
                        
                        Picker(selection: $viewModel.aiModel) {
                            ForEach(aiService.getAvailableModels(for: provider), id: \.self) { model in
                                Text(model).tag(model as String?)
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
                    } else {
                        NavigationLink(destination: AddAPIKeyView(
                            provider: provider,
                            aiService: aiService, onSave: { provider in
                                viewModel.updateModel(provider.defaultModel)
                            })) {
                            HStack {
                                Image(systemName: "key")
                                Text("Add API Key")
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIModeConfigurationView(mode: AIEnhanceMode.defaultMode, aiService: AIService())
    }
}
