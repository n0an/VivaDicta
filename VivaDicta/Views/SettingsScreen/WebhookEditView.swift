//
//  WebhookEditView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.11.05
//

import SwiftUI

/// Sheet for adding or editing a webhook: name, https URL, optional bearer
/// token, enabled toggle, a "Send test" button and, when editing, the last
/// delivery result and delete.
struct WebhookEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WebhookEditViewModel
    @State private var isConfirmingDelete = false

    private static let urlPlaceholder = "https://example.com/hooks/vivadicta"

    init(webhook: WebhookDefinition?) {
        _viewModel = State(initialValue: WebhookEditViewModel(webhook: webhook))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                    TextField(Self.urlPlaceholder, text: $viewModel.urlString, axis: .vertical)
                        .lineLimit(1...4)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Toggle("Enabled", isOn: $viewModel.isEnabled)
                } footer: {
                    if let message = viewModel.urlErrorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                    } else {
                        Text("VivaDicta POSTs each transcription as JSON to this URL. Only https is supported.")
                    }
                }

                Section {
                    SecureField(viewModel.hasSavedToken ? "Saved - type to replace" : "Bearer token (optional)",
                                text: $viewModel.tokenInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if viewModel.hasSavedToken {
                        Button("Remove Saved Token", role: .destructive) {
                            viewModel.tokenInput = ""
                            viewModel.removesSavedToken = true
                        }
                    }
                } header: {
                    Text("Authorization")
                } footer: {
                    Text("Sent as \"Authorization: Bearer <token>\". Stored in the Keychain on this device only.")
                }

                Section {
                    Button {
                        Task { await viewModel.sendTest() }
                    } label: {
                        HStack {
                            Text("Send Test")
                            Spacer()
                            if viewModel.testState == .sending {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.testState == .sending)

                    WebhookTestResultView(state: viewModel.testState)
                } footer: {
                    Text("Posts a sample payload to the URL and token above, even before you save.")
                }

                if let status = viewModel.lastStatus {
                    Section("Last Delivery") {
                        WebhookStatusLabel(status: status)
                    }
                }

                if viewModel.isEditing {
                    Section {
                        Button("Delete Webhook", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }

                if let saveError = viewModel.saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Webhook" : "Add Webhook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save() {
                            HapticManager.success()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .confirmationDialog("Delete this webhook?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    viewModel.delete()
                    dismiss()
                }
            } message: {
                Text("Modes that send to it will stop sending. Pending deliveries are discarded.")
            }
        }
    }
}

private struct WebhookTestResultView: View {
    let state: WebhookEditViewModel.TestState

    var body: some View {
        switch state {
        case .idle, .sending:
            EmptyView()
        case .finished(let statusCode, let body):
            VStack(alignment: .leading, spacing: 4) {
                Label("HTTP \(statusCode)", systemImage: (200..<300).contains(statusCode) ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle((200..<300).contains(statusCode) ? .green : .red)
                if !body.isEmpty {
                    Text(body)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }
}

/// One line describing a webhook's last delivery result.
struct WebhookStatusLabel: View {
    let status: WebhookDeliveryStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch status.outcome {
            case .delivered:
                Label("Delivered\(status.statusCode.map { " (HTTP \($0))" } ?? "")", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .retrying:
                Label("Retrying: \(status.message ?? "unknown error")", systemImage: "arrow.clockwise.circle.fill")
                    .foregroundStyle(.orange)
            case .failed:
                Label("Failed: \(status.message ?? "unknown error")", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            }
            Text(status.date, format: .relative(presentation: .named))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
