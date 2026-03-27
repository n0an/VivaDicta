//
//  CLIServerConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.27
//

import SwiftUI

struct CLIServerConfigurationView: View {
    let aiService: AIService

    // Server state
    @State private var isServerEnabled = UserDefaults.standard.bool(forKey: ClaudeCLIServerClient.isEnabledKey)
    @State private var serverURL = UserDefaults.standard.string(forKey: ClaudeCLIServerClient.serverURLKey) ?? ""
    @State private var serverToken = KeychainService.shared.getString(forKey: ClaudeCLIServerClient.authTokenKeychainKey, syncable: false) ?? ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: Bool?
    @State private var showCLIWarning = false

    // Health response for per-CLI availability
    @State private var healthResponse: ClaudeCLIServerClient.HealthResponse?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue.gradient)

                    Text("Mac CLI Server")
                        .font(.title2)

                    if isServerEnabled && ClaudeCLIServerClient.isVerified {
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
                if isServerEnabled && ClaudeCLIServerClient.isVerified {
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
        .navigationTitle("Mac CLI Server")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Re-fetch health on appear if server is connected
            if isServerEnabled && ClaudeCLIServerClient.isVerified && healthResponse == nil {
                healthResponse = await ClaudeCLIServerClient.fetchHealth()
                if let health = healthResponse {
                    ClaudeCLIServerClient.saveAvailability(from: health)
                    aiService.refreshConnectedProviders()
                }
            }
        }
        .alert("Usage Notice", isPresented: $showCLIWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Enable") {
                isServerEnabled = true
                UserDefaults.standard.set(true, forKey: ClaudeCLIServerClient.isEnabledKey)
            }
        } message: {
            Text("CLI tools (Claude, Codex, Gemini) are designed for software development use. Using them for general text processing may fall outside the intended use and could lead to account restrictions.\n\nBy enabling this feature you proceed at your own risk.")
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)

            Text("Connect to VivaDicta on your Mac to use CLI tools (Claude, Codex, Gemini) for AI processing. Same WiFi or Tailscale required.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Enable CLI Server", isOn: Binding(
                get: { isServerEnabled },
                set: { newValue in
                    if newValue {
                        showCLIWarning = true
                    } else {
                        isServerEnabled = false
                        UserDefaults.standard.set(false, forKey: ClaudeCLIServerClient.isEnabledKey)
                        UserDefaults.standard.set(false, forKey: ClaudeCLIServerClient.isVerifiedKey)
                        connectionTestResult = nil
                        healthResponse = nil
                        ClaudeCLIServerClient.clearAvailability()
                        aiService.refreshConnectedProviders()
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
            Text("Available CLIs")
                .font(.headline)

            Text("CLIs detected on your Mac. Each can be individually shared from the macOS app.")
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

            Text("The Mac CLI Server runs on your Mac inside VivaDicta. Your iPhone connects to it over the local network and routes AI requests through the CLI tools installed on your Mac — using your existing subscriptions with no API keys needed.")
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

    private func saveAndTestConnection() {
        UserDefaults.standard.set(serverURL, forKey: ClaudeCLIServerClient.serverURLKey)
        KeychainService.shared.save(serverToken, forKey: ClaudeCLIServerClient.authTokenKeychainKey, syncable: false)

        Task {
            isTestingConnection = true
            let success = await ClaudeCLIServerClient.testConnection(provider: "any")
            connectionTestResult = success
            UserDefaults.standard.set(success, forKey: ClaudeCLIServerClient.isVerifiedKey)
            isTestingConnection = false
            aiService.refreshConnectedProviders()

            // Fetch health details for CLI availability
            if success {
                let health = await ClaudeCLIServerClient.fetchHealth()
                healthResponse = health
                if let health {
                    ClaudeCLIServerClient.saveAvailability(from: health)
                }
                HapticManager.success()
            } else {
                healthResponse = nil
                ClaudeCLIServerClient.clearAvailability()
                HapticManager.error()
            }
        }
    }
}
