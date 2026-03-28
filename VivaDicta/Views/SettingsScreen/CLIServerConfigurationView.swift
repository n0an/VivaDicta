//
//  CLIServerConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.27
//

import SwiftUI

struct CLIServerConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let aiService: AIService

    // Server state
    @State private var isServerEnabled = UserDefaults.standard.bool(forKey: VivAgentsClient.isEnabledKey)
    @State private var serverURL = UserDefaults.standard.string(forKey: VivAgentsClient.serverURLKey) ?? ""
    @State private var serverToken = KeychainService.shared.getString(forKey: VivAgentsClient.authTokenKeychainKey, syncable: false) ?? ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: Bool?
    @State private var showCLIWarning = false
    @State private var hasUnsavedChanges = false

    // Health response for per-CLI availability
    @State private var healthResponse: VivAgentsClient.HealthResponse?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.gradient)

                    Text("VivAgents Server")
                        .font(.title2)

                    if isServerEnabled && VivAgentsClient.isVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                // Connection form
                connectionSection

                // CLI availability
                if isServerEnabled && VivAgentsClient.isVerified {
                    availabilitySection
                }

                // Info
                infoSection
            }
            .padding()
        }
        .contentShape(.rect)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("VivAgents Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveSettings()
                }
                .disabled(!hasUnsavedChanges)
                .bold()
            }
        }
        .task {
            // Re-fetch health on appear if server is connected
            if isServerEnabled && VivAgentsClient.isVerified && healthResponse == nil {
                healthResponse = await VivAgentsClient.fetchHealth()
                if let health = healthResponse {
                    VivAgentsClient.saveAvailability(from: health)
                    aiService.refreshConnectedProviders()
                }
            }
        }
        .alert("Usage Notice", isPresented: $showCLIWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Enable") {
                isServerEnabled = true
                hasUnsavedChanges = true
            }
        } message: {
            Text("CLI agents (Claude, Codex, Gemini) are designed for software development use. Using them for general text processing may fall outside the intended use and could lead to account restrictions.\n\nBy enabling this feature you proceed at your own risk.")
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)

            Text("Connect to a server running CLI agents (Claude, Codex, Gemini) for AI processing. Can be your Mac with VivaDicta or a remote server.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Enable VivAgents Server", isOn: Binding(
                get: { isServerEnabled },
                set: { newValue in
                    if newValue {
                        showCLIWarning = true
                    } else {
                        isServerEnabled = false
                        hasUnsavedChanges = true
                    }
                }
            ))

            if isServerEnabled {
                TextField("Server URL (e.g. http://192.168.1.5:3456)", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                    .background {
                        Capsule()
                            .stroke(.gray, lineWidth: 0.5)
                    }
                    .onChange(of: serverURL) { _, _ in
                        connectionTestResult = nil
                    }

                SecureField("Auth Token", text: $serverToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background {
                        Capsule()
                            .stroke(.gray, lineWidth: 0.5)
                    }
                    .onChange(of: serverToken) { _, _ in
                        connectionTestResult = nil
                    }

                HStack {
                    if #available(iOS 26.0, *) {
                        Button {
                            saveAndTestConnection()
                        } label: {
                            HStack(spacing: 6) {
                                if isTestingConnection {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("Test & Save")
                                    .font(.headline.weight(.medium))
                            }
                        }
                        .disabled(serverURL.isEmpty || isTestingConnection)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            saveAndTestConnection()
                        } label: {
                            HStack(spacing: 6) {
                                if isTestingConnection {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("Test & Save")
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
                        .disabled(serverURL.isEmpty || isTestingConnection)
                        .buttonStyle(.plain)
                    }

                    if let result = connectionTestResult {
                        HStack(spacing: 4) {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result ? .green : .red)
                            Text(result ? "Connected" : "Failed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
    }

    // MARK: - CLI Availability Section

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Agents")
                .font(.headline)

            Text("CLI agents detected on the server. Each can be individually enabled from the server configuration.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                cliRow(name: "Claude CLI", provider: "Anthropic", available: healthResponse?.claudeAvailable ?? false)
                cliRow(name: "Codex CLI", provider: "OpenAI", available: healthResponse?.codexAvailable ?? false)
                cliRow(name: "Gemini CLI", provider: "Google", available: healthResponse?.geminiAvailable ?? false)
            }

            if let version = healthResponse?.version {
                Text("Server v\(version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
    }

    private func cliRow(name: String, provider: String, available: Bool) -> some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(available ? .green : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.callout)
                Text(provider)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(available ? "Available" : "Not found")
                .font(.caption)
                .foregroundStyle(available ? .green : .secondary)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How it works", systemImage: "info.circle")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Text("The VivAgents Server hosts CLI agents (Claude, Codex, Gemini) and exposes them over the network. Your iPhone or iPad connects to it and routes AI requests through the agents — using your existing subscriptions with no API keys needed.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
    }

    // MARK: - Actions

    private func saveSettings() {
        UserDefaults.standard.set(isServerEnabled, forKey: VivAgentsClient.isEnabledKey)

        if !isServerEnabled {
            UserDefaults.standard.set(false, forKey: VivAgentsClient.isVerifiedKey)
            connectionTestResult = nil
            healthResponse = nil
            VivAgentsClient.clearAvailability()
        }

        aiService.refreshConnectedProviders()
        hasUnsavedChanges = false
        HapticManager.success()
    }

    private func saveAndTestConnection() {
        UserDefaults.standard.set(isServerEnabled, forKey: VivAgentsClient.isEnabledKey)
        UserDefaults.standard.set(serverURL, forKey: VivAgentsClient.serverURLKey)
        KeychainService.shared.save(serverToken, forKey: VivAgentsClient.authTokenKeychainKey, syncable: false)
        hasUnsavedChanges = false

        Task {
            isTestingConnection = true
            let success = await VivAgentsClient.testConnection(provider: "any")
            connectionTestResult = success
            UserDefaults.standard.set(success, forKey: VivAgentsClient.isVerifiedKey)
            isTestingConnection = false
            aiService.refreshConnectedProviders()

            // Fetch health details for CLI availability
            if success {
                let health = await VivAgentsClient.fetchHealth()
                healthResponse = health
                if let health {
                    VivAgentsClient.saveAvailability(from: health)
                }
                HapticManager.success()
            } else {
                healthResponse = nil
                VivAgentsClient.clearAvailability()
                HapticManager.error()
            }
        }
    }
}
