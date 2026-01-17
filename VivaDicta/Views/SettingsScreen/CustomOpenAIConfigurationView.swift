//
//  CustomOpenAIConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.17
//

import SwiftUI
import os

private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "CustomOpenAIConfig")

struct CustomOpenAIConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let aiService: AIService

    @State private var endpointURL: String = ""
    @State private var modelName: String = ""
    @State private var apiKey: String = ""
    @State private var isChecking = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var showingClearConfirmation = false

    enum ConnectionStatus: Equatable {
        case unknown
        case checking
        case connected
        case failed(message: String)
        case invalidURL
        case missingModel
    }

    private var isConfigured: Bool {
        !aiService.customOpenAIEndpointURL.isEmpty && !aiService.customOpenAIModelName.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("Custom OpenAI")
                .font(.title2)

            Text("OpenAI-Compatible API")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 20) {
                    // Endpoint URL input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Endpoint URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("https://api.example.com", text: $endpointURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .padding()
                            .background {
                                Capsule()
                                    .stroke(urlFieldBorderColor, lineWidth: urlFieldBorderWidth)
                            }
                            .onChange(of: endpointURL) { _, newValue in
                                if !newValue.isEmpty && !isValidURL(newValue) {
                                    connectionStatus = .invalidURL
                                } else if connectionStatus == .invalidURL {
                                    connectionStatus = .unknown
                                }
                            }

                        Text("The base URL of your OpenAI-compatible API.\nExample: https://api.openai.com or http://localhost:8080")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Model Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("gpt-4, llama-3.1-70b, etc.", text: $modelName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background {
                                Capsule()
                                    .stroke(modelFieldBorderColor, lineWidth: modelFieldBorderWidth)
                            }
                            .onChange(of: modelName) { _, newValue in
                                if newValue.isEmpty && connectionStatus != .unknown {
                                    connectionStatus = .missingModel
                                } else if connectionStatus == .missingModel && !newValue.isEmpty {
                                    connectionStatus = .unknown
                                }
                            }

                        Text("The model identifier as expected by your API server.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // API Key input (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key (Optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        SecureField("sk-...", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .padding()
                            .background {
                                Capsule()
                                    .stroke(Color.gray, lineWidth: 0.5)
                            }

                        Text("Leave empty if your server doesn't require authentication.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Connection status
                    connectionStatusView
                }
                .padding(.horizontal)
            }

            // Action buttons
            VStack(spacing: 12) {
                // Test & Save button
                if #available(iOS 26.0, *) {
                    Button {
                        testAndSave()
                    } label: {
                        HStack {
                            if case .checking = connectionStatus {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(connectionStatus == .checking ? "Connecting..." : "Test & Save")
                                .font(.headline.weight(.medium))
                        }
                    }
                    .disabled(isChecking || !canTestConnection)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                    .buttonStyle(.plain)
                } else {
                    Button {
                        testAndSave()
                    } label: {
                        HStack {
                            if case .checking = connectionStatus {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(connectionStatus == .checking ? "Connecting..." : "Test & Save")
                                .font(.headline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background {
                            Capsule()
                                .stroke(.blue, lineWidth: 2)
                        }
                    }
                    .disabled(isChecking || !canTestConnection)
                    .buttonStyle(.plain)
                }

                // Clear Configuration button (only shown when configured)
                if isConfigured {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear Configuration", systemImage: "trash")
                            .font(.subheadline)
                    }
                }
            }

            Spacer()

            // Help text
            VStack(spacing: 8) {
                Text("Connect to any OpenAI-compatible API server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Supports LiteLLM, vLLM, Ollama, and other compatible servers.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom)
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("Custom OpenAI")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadExistingConfiguration()
        }
        .confirmationDialog(
            "Clear Configuration",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                clearConfiguration()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your Custom OpenAI configuration and disable AI enhancement for any modes using it.")
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch connectionStatus {
        case .unknown:
            EmptyView()

        case .checking:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Testing connection...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .connected:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Connection successful")
                Text("Connected successfully")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .failed(let message):
            HStack(alignment: .top) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Connection failed")
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

        case .invalidURL:
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Invalid URL")
                Text("Invalid URL. Use http:// or https://")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .missingModel:
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Missing model name")
                Text("Please enter a model name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canTestConnection: Bool {
        !endpointURL.isEmpty && !modelName.isEmpty && connectionStatus != .invalidURL
    }

    private var urlFieldBorderColor: Color {
        switch connectionStatus {
        case .invalidURL:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        default:
            return .gray
        }
    }

    private var urlFieldBorderWidth: CGFloat {
        switch connectionStatus {
        case .unknown:
            return 0.5
        default:
            return 1.5
        }
    }

    private var modelFieldBorderColor: Color {
        switch connectionStatus {
        case .missingModel:
            return .orange
        case .connected:
            return .green
        default:
            return .gray
        }
    }

    private var modelFieldBorderWidth: CGFloat {
        switch connectionStatus {
        case .unknown:
            return 0.5
        case .connected, .missingModel:
            return 1.5
        default:
            return 0.5
        }
    }

    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return false
        }
        return true
    }

    private func loadExistingConfiguration() {
        endpointURL = aiService.customOpenAIEndpointURL
        modelName = aiService.customOpenAIModelName
        if let existingKey = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kAPIKeyTemplate + AIProvider.customOpenAI.rawValue) {
            apiKey = existingKey
        }

        // Auto-check if already configured
        if isConfigured {
            Task {
                await testConnection(saveOnSuccess: false)
            }
        }
    }

    private func testAndSave() {
        isChecking = true
        Task {
            await testConnection(saveOnSuccess: true)
        }
    }

    private func testConnection(saveOnSuccess: Bool) async {
        logger.notice("🔧 CustomOpenAI Config - Starting test connection")
        logger.notice("🔧 CustomOpenAI Config - Endpoint URL: '\(endpointURL)'")
        logger.notice("🔧 CustomOpenAI Config - Model Name: '\(modelName)'")
        logger.notice("🔧 CustomOpenAI Config - API Key length: \(apiKey.count)")

        guard isValidURL(endpointURL) else {
            logger.error("🔧 CustomOpenAI Config - Invalid URL")
            await MainActor.run {
                connectionStatus = .invalidURL
                isChecking = false
            }
            return
        }

        guard !modelName.isEmpty else {
            logger.error("🔧 CustomOpenAI Config - Missing model name")
            await MainActor.run {
                connectionStatus = .missingModel
                isChecking = false
            }
            return
        }

        await MainActor.run {
            connectionStatus = .checking
        }

        HapticManager.lightImpact()

        // Save configuration to test
        let apiKeyStorageKey = AppGroupCoordinator.kAPIKeyTemplate + AIProvider.customOpenAI.rawValue
        logger.notice("🔧 CustomOpenAI Config - API Key storage key: '\(apiKeyStorageKey)'")

        await MainActor.run {
            aiService.customOpenAIEndpointURL = endpointURL
            aiService.customOpenAIModelName = modelName
            logger.notice("🔧 CustomOpenAI Config - Saved endpoint URL to AIService: '\(aiService.customOpenAIEndpointURL)'")
            logger.notice("🔧 CustomOpenAI Config - Saved model name to AIService: '\(aiService.customOpenAIModelName)'")

            if !apiKey.isEmpty {
                UserDefaultsStorage.shared.set(apiKey, forKey: apiKeyStorageKey)
                logger.notice("🔧 CustomOpenAI Config - Saved API key to UserDefaults")
            } else {
                UserDefaultsStorage.shared.removeObject(forKey: apiKeyStorageKey)
                logger.notice("🔧 CustomOpenAI Config - Removed API key from UserDefaults (empty)")
            }
        }

        logger.notice("🔧 CustomOpenAI Config - Calling verifyCustomOpenAISetup...")
        let result = await aiService.verifyCustomOpenAISetup()
        logger.notice("🔧 CustomOpenAI Config - Result: success=\(result.success), message='\(result.message)'")

        await MainActor.run {
            if result.success {
                connectionStatus = .connected
                if saveOnSuccess {
                    aiService.refreshConnectedProviders()
                    HapticManager.success()
                }
            } else {
                connectionStatus = .failed(message: result.message)
                if saveOnSuccess {
                    // Don't clear on failure - let user fix the issue
                    HapticManager.error()
                }
            }
            isChecking = false
        }
    }

    private func clearConfiguration() {
        HapticManager.heavyImpact()
        aiService.clearCustomOpenAIConfiguration()
        aiService.disableCustomOpenAIEnhancementForAllModes()
        aiService.refreshConnectedProviders()

        endpointURL = ""
        modelName = ""
        apiKey = ""
        connectionStatus = .unknown
    }
}

#Preview {
    NavigationStack {
        CustomOpenAIConfigurationView(aiService: AIService())
    }
}
