//
//  AIProvidersView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.14
//

import SwiftUI

struct AIProviders: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            // On-Device Section (Apple Foundation Model)
            if AppleFoundationModelAvailability.isAvailable {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)

                        Text(AIProvider.apple.displayName)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green.gradient)
                            Text("Ready to use. Private & Free.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("On-Device")
                } footer: {
                    Text("Apple's Foundation Model runs entirely on your device. Your data never leaves your device, ensuring complete privacy. No API key or subscription required — it's completely free.")
                }
            }

            // Cloud Section
            Section("Cloud") {
                ForEach(AIProvider.cloudProviders) { provider in
                    NavigationLink(value: provider) {
                        HStack(spacing: 12) {
                            if let iconName = provider.iconName {
                                Image(iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            } else if provider == .customOpenAI {
                                Image(systemName: "server.rack")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 28)
                            }

                            Text(provider.displayName)

                            Spacer()

                            // Ollama has special status display
                            if provider == .ollama {
                                if appState.aiService.ollamaModels.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gear")
                                            .foregroundStyle(.orange)
                                        Text("Configure")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("\(appState.aiService.ollamaModels.count) models")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else if provider == .customOpenAI {
                                // Custom OpenAI has special status display
                                if appState.aiService.customOpenAIEndpointURL.isEmpty || appState.aiService.customOpenAIModelName.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gear")
                                            .foregroundStyle(.orange)
                                        Text("Configure")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Configured")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else if !appState.aiService.connectedProviders.contains(provider) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Add API Key")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: AIProvider.self) { provider in
            if provider == .ollama {
                OllamaConfigurationView(aiService: appState.aiService)
            } else if provider == .customOpenAI {
                CustomOpenAIConfigurationView(aiService: appState.aiService)
            } else {
                AddAPIKeyView(
                    provider: provider,
                    aiService: appState.aiService,
                    onSave: { _ in }
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIProviders()
    }
}
