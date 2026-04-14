//
//  AddCustomTranscriptionModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.17
//

import SwiftUI

struct AddCustomTranscriptionModelView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: () -> Void

    @State private var apiEndpoint: String = ""
    @State private var apiKey: String = ""
    @State private var modelName: String = ""
    @State private var isMultilingual: Bool = true
    @State private var isChecking = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var showingClearConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case apiEndpoint
        case apiKey
        case modelName
    }

    private var manager: CustomTranscriptionModelManager {
        CustomTranscriptionModelManager.shared
    }

    enum ConnectionStatus: Equatable {
        case unknown
        case checking
        case connected
        case failed(message: String)
        case invalidURL
        case validationError(message: String)
    }

    private var canSave: Bool {
        !apiEndpoint.trimmingCharacters(in: .whitespaces).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespaces).isEmpty &&
        connectionStatus != .invalidURL
    }

    private var hasExistingConfiguration: Bool {
        manager.isConfigured
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Icon
                Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                Text("Custom Model")
                    .font(.title2)

                Text("OpenAI-Compatible Transcription API")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Connection status
                connectionStatusView

                ScrollView {
                    VStack(spacing: 20) {
                        // API Endpoint input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Endpoint")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("", text: $apiEndpoint)
                                .focused($focusedField, equals: .apiEndpoint)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding()
                                .background {
                                    Capsule()
                                        .stroke(urlFieldBorderColor, lineWidth: urlFieldBorderWidth)
                                }
                                .onChange(of: apiEndpoint) { _, newValue in
                                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty && !isValidURL(trimmed) {
                                        connectionStatus = .invalidURL
                                    } else if connectionStatus == .invalidURL {
                                        connectionStatus = .unknown
                                    }
                                }

                            Text("The full transcription endpoint URL")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // API Key input (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key (Optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            SecureField("your-api-key", text: $apiKey)
                                .focused($focusedField, equals: .apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .privacySensitive()
                                .padding()
                                .background {
                                    Capsule()
                                        .stroke(Color.gray, lineWidth: 0.5)
                                }

                            Text("Leave empty if your server doesn't require authentication")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // Model Name input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("large-v3-turbo", text: $modelName)
                                .focused($focusedField, equals: .modelName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding()
                                .background {
                                    Capsule()
                                        .stroke(Color.gray, lineWidth: 0.5)
                                }

                            Text("The model identifier as expected by your API server")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // Multilingual toggle
                        Toggle(isOn: $isMultilingual) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Multilingual Model")
                                    .font(.subheadline)
                                Text("Enable if the model supports multiple languages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                }

                // Action buttons
                VStack(spacing: 12) {
                    // Save button
                    if #available(iOS 26.0, *) {
                        Button {
                            saveConfiguration()
                        } label: {
                            HStack {
                                if case .checking = connectionStatus {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(connectionStatus == .checking ? "Saving..." : "Save")
                                    .font(.headline.weight(.medium))
                            }
                        }
                        .disabled(isChecking || !canSave)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            saveConfiguration()
                        } label: {
                            HStack {
                                if case .checking = connectionStatus {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(connectionStatus == .checking ? "Saving..." : "Save")
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
                        .disabled(isChecking || !canSave)
                        .buttonStyle(.plain)
                    }

                    // Clear configuration button (only if configured)
                    if hasExistingConfiguration {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear Configuration", systemImage: "trash")
                                .font(.subheadline)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
            .navigationTitle("Custom Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                        .labelStyle(.iconOnly)
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
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
                Text("This will remove all custom model settings.")
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
                Text("Validating...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .connected:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Saved successfully")
                Text("Configuration saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .failed(let message):
            HStack(alignment: .top) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Save failed")
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

        case .validationError(let message):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Validation error")
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
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
        let model = manager.customModel
        apiEndpoint = model.apiEndpoint
        modelName = model.modelName
        isMultilingual = model.isMultilingual

        if let existingKey = manager.apiKey {
            apiKey = existingKey
        }
    }

    private func saveConfiguration() {
        let trimmedEndpoint = apiEndpoint.trimmingCharacters(in: .whitespaces)
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespaces)
        let trimmedModelName = modelName.trimmingCharacters(in: .whitespaces)

        // Validate
        let errors = manager.validateConfiguration(apiEndpoint: trimmedEndpoint, modelName: trimmedModelName)

        if !errors.isEmpty {
            connectionStatus = .validationError(message: errors.first ?? "Validation failed")
            HapticManager.error()
            return
        }

        isChecking = true
        connectionStatus = .checking
        HapticManager.lightImpact()

        let success = manager.saveConfiguration(
            apiEndpoint: trimmedEndpoint,
            apiKey: trimmedApiKey,
            modelName: trimmedModelName,
            isMultilingual: isMultilingual
        )

        handleSaveResult(success)
    }

    private func handleSaveResult(_ success: Bool) {
        isChecking = false

        if success {
            connectionStatus = .connected
            HapticManager.success()

            // Dismiss after short delay
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run {
                    onSave()
                    dismiss()
                }
            }
        } else {
            connectionStatus = .failed(message: "Failed to save configuration")
            HapticManager.error()
        }
    }

    private func clearConfiguration() {
        HapticManager.heavyImpact()
        manager.clearConfiguration()
        onSave()
        dismiss()
    }
}

#Preview {
    AddCustomTranscriptionModelView(onSave: {})
}
