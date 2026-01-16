//
//  OllamaConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.16
//

import SwiftUI

struct OllamaConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let aiService: AIService

    @State private var serverURL: String = ""
    @State private var isChecking = false
    @State private var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus: Equatable {
        case unknown
        case checking
        case connected(modelCount: Int)
        case failed(message: String)
        case invalidURL
    }

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image("ollama")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .padding(.top, 8)

            Text("Ollama")
                .font(.title2)

            Text("Local AI Server")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Server URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("Server URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Format: http://host:11434, or https://host:11434\n(default Ollama port is 11434)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                TextField("http", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                    .background {
                        Capsule()
                            .stroke(connectionStatus.borderColor, lineWidth: connectionStatus.borderWidth)
                    }
                    .onChange(of: serverURL) { _, newValue in
                        if newValue.isEmpty {
                            connectionStatus = .unknown
                            aiService.ollamaServerURL = AIProvider.ollamaDefaultServerURL
                        } else if isValidOllamaURL(newValue) {
                            connectionStatus = .unknown
                            aiService.ollamaServerURL = newValue
                        } else {
                            connectionStatus = .invalidURL
                        }
                    }
            }
            .padding(.horizontal)

            // Connection status
            connectionStatusView
                .padding(.horizontal)

            // Test Connection button
            if #available(iOS 26.0, *) {
                Button {
                    isChecking = true
                    Task {
                        await checkConnection()
                    }
                } label: {
                    HStack {
                        if case .checking = connectionStatus {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(connectionStatus == .checking ? "Checking..." : "Test Connection")
                            .font(.headline.weight(.medium))
                    }
                }
                .disabled(isChecking || connectionStatus == .invalidURL)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                .buttonStyle(.plain)
            } else {
                Button {
                    isChecking = true
                    Task {
                        await checkConnection()
                    }
                } label: {
                    HStack {
                        if case .checking = connectionStatus {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(connectionStatus == .checking ? "Checking..." : "Test Connection")
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
                .disabled(isChecking || connectionStatus == .invalidURL)
                .buttonStyle(.plain)
            }

            // Models list (if connected)
            if case .connected = connectionStatus, !aiService.ollamaModels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Models")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(aiService.ollamaModels, id: \.self) { model in
                                Text(model)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }

            Spacer()

            // Help text
            VStack(spacing: 8) {
                Text("Ollama runs AI models locally on your Mac or server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Link("Get Ollama →", destination: URL(string: "https://ollama.com")!)
                    .font(.caption)
            }
            .padding(.bottom)
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("Ollama")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            serverURL = aiService.ollamaServerURL
            // Auto-check connection on appear
            isChecking = true
            Task {
                await checkConnection()
            }
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
                Text("Checking connection...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .connected(let modelCount):
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Connection successful")
                Text("Connected • \(modelCount) model\(modelCount == 1 ? "" : "s") available")
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
        }
    }

    private func isValidOllamaURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return false
        }
        return true
    }

    private func checkConnection() async {
        guard connectionStatus != .invalidURL else {
            isChecking = false
            return
        }

        connectionStatus = .checking

        HapticManager.lightImpact()

        let result = await aiService.verifyOllamaSetup()

        await MainActor.run {
            if result.success {
                connectionStatus = .connected(modelCount: aiService.ollamaModels.count)
                HapticManager.success()
            } else {
                connectionStatus = .failed(message: result.message)
                // Clear models so other screens know Ollama is not ready
                aiService.ollamaModels = []
                HapticManager.error()
            }
            isChecking = false
        }
    }
}

extension OllamaConfigurationView.ConnectionStatus {
    var borderColor: Color {
        switch self {
        case .unknown, .checking:
            return .gray
        case .connected:
            return .green
        case .failed:
            return .red
        case .invalidURL:
            return .orange
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .unknown:
            return 0.5
        case .checking, .connected, .failed, .invalidURL:
            return 1.5
        }
    }
}

#Preview {
    NavigationStack {
        OllamaConfigurationView(aiService: AIService())
    }
}
