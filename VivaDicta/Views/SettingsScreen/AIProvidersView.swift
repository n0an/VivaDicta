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
            if AppleFoundationModelAvailability.isAvailable {
                Section {
                    HStack {
                        Text(AIProvider.apple.displayName)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green.gradient)
                            Text("Private & Free")
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

            Section("Cloud") {
                ForEach(AIProvider.cloudProviders) { provider in
                    NavigationLink(value: provider) {
                        HStack {
                            Text(provider.displayName)

                            Spacer()

                            if !provider.hasAPIKey {
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
            AddAPIKeyView(
                provider: provider,
                aiService: appState.aiService,
                onSave: { _ in }
            )
        }
    }
}

#Preview {
    NavigationStack {
        AIProviders()
    }
}
