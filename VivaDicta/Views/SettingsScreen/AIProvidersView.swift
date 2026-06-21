//
//  AIProvidersView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.14
//

import SwiftUI
import AICore
import AIProviders
import DesignSystem

private enum AIProviderType: String, CaseIterable, Identifiable {
    case local
    case cloud
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct AIProviders: View {
    @Environment(AppState.self) private var appState
    @State private var refreshID = UUID()
    @State private var providerType: AIProviderType = .local
    @State private var gemmaModel = LiteRTGemmaModelViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Provider type", selection: $providerType) {
                ForEach(AIProviderType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .onChange(of: providerType) { _, _ in
                HapticManager.selectionChanged()
            }

            if providerType == .local {
                ScrollView {
                    VStack(spacing: 16) {
                        AppleProviderCard()
                            .padding(.horizontal)
                        GemmaVariantCard(variant: .e2b, model: gemmaModel)
                            .padding(.horizontal)
                        GemmaVariantCard(variant: .e4b, model: gemmaModel)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                List {
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
                                // Must have URL, model, AND be verified (test passed)
                                let isConfigured = !appState.aiService.customOpenAIEndpointURL.isEmpty &&
                                                   !appState.aiService.customOpenAIModelName.isEmpty &&
                                                   appState.aiService.customOpenAIIsVerified
                                if isConfigured {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Configured")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gear")
                                            .foregroundStyle(.orange)
                                        Text("Configure")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else if provider == .openAI && appState.aiService.isOpenAISignedIn {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("OAuth")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else if provider == .gemini && appState.aiService.isGeminiSignedIn {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Google")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else if provider == .anthropic && VivAgentsClient.isEnabled && VivAgentsClient.isAnthropicCliActive {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("VivAgents")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else if provider == .openAI && VivAgentsClient.isEnabled && VivAgentsClient.isCodexCliActive {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("VivAgents")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else if provider == .gemini && VivAgentsClient.isEnabled && VivAgentsClient.isGeminiCliActive {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("VivAgents")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else if provider == .copilot && appState.aiService.isCopilotSignedIn {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    if let username = appState.aiService.copilotUsername {
                                        Text("@\(username)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else if provider == .copilot && !appState.aiService.isCopilotSignedIn {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.badge.key")
                                        .foregroundStyle(.orange)
                                    Text("Sign In")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else if !appState.aiService.connectedProviders.contains(provider) {
                                if provider == .anthropic || provider == .openAI || provider == .gemini {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gear")
                                            .foregroundStyle(.orange)
                                        Text("Configure")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
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

            // VivAgents Server Section
            Section {
                NavigationLink {
                    CLIServerConfigurationView(aiService: appState.aiService)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.title2)
                            .foregroundStyle(.blue.gradient)
                            .frame(width: 28, height: 28)

                        Text("VivAgents Server")

                        Spacer()

                        if VivAgentsClient.isEnabled && VivAgentsClient.isVerified {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Connected")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                    .foregroundStyle(.orange)
                                Text("Configure")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Route AI processing through CLI agents (Anthropic, Codex, Gemini) running on your Mac or remote server. Uses your existing accounts — no API keys needed.")
            }
                }
            }
        }
        .id(refreshID)
        .onAppear {
            refreshID = UUID()
            appState.aiService.refreshConnectedProviders()
        }
        .task {
            await gemmaModel.refresh()
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: AIProvider.self) { provider in
            if provider == .ollama {
                OllamaConfigurationView(aiService: appState.aiService)
            } else if provider == .customOpenAI {
                CustomOpenAIConfigurationView(aiService: appState.aiService)
            } else if provider == .anthropic {
                AnthropicConfigurationView(aiService: appState.aiService)
            } else if provider == .openAI {
                OpenAIConfigurationView(aiService: appState.aiService)
            } else if provider == .gemini {
                GeminiConfigurationView(aiService: appState.aiService)
            } else if provider == .copilot {
                CopilotConfigurationView(aiService: appState.aiService)
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

// MARK: - Apple Intelligence Setup

/// Card-style row for Apple's on-device Foundation Model, matching the Gemma
/// cards. Shows the privacy/free description inside the card. Hidden on devices
/// that can't run Apple Intelligence at all.
private struct AppleProviderCard: View {
    private var status: AppleFoundationModelAvailability { AppleFoundationModelAvailability.currentStatus }

    private var shouldShow: Bool {
        switch status {
        case .available, .appleIntelligenceNotEnabled, .modelNotReady: true
        case .deviceNotEligible, .unavailable: false
        }
    }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.title3)
                            Text(AIProvider.apple.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        statusLabel
                        RecommendedBadge()
                    }
                    Spacer()
                }

                Text(descriptionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .modelCardBackground()
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .available:
            Label("Ready to use. Private & Free.", systemImage: "checkmark.shield.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        default:
            Label("Setup needed", systemImage: "gear")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }

    private var descriptionText: String {
        switch status {
        case .available:
            "Apple's Foundation Model runs entirely on your device. Your data never leaves your device, ensuring complete privacy. No API key or account required — it's completely free."
        case .modelNotReady:
            "Apple Intelligence is enabled but the Foundation Model is still downloading. It will be available shortly."
        default:
            "Go to Settings > Apple Intelligence & Siri to enable Apple Intelligence and use the free, private on-device Foundation Model."
        }
    }
}

#Preview {
    NavigationStack {
        AIProviders()
    }
}
