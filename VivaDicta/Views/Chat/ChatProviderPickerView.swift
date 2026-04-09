//
//  ChatProviderPickerView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//

import SwiftUI

/// Compact provider and model selector for the chat header.
struct ChatProviderPickerView: View {
    @Bindable var viewModel: ChatViewModel
    var aiService: AIService

    @State private var showProviderPicker = false
    @State private var showModelPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Provider button
                Button {
                    showProviderPicker = true
                } label: {
                    HStack(spacing: 6) {
                        providerIcon
                        Text(viewModel.selectedProvider?.displayName ?? "Select Provider")
                            .font(.subheadline)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.primary)
                }

                // Model button
                if viewModel.selectedProvider != nil {
                    Button {
                        showModelPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedModel ?? "Select Model")
                                .font(.caption)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Context fill indicator
                contextIndicator
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()
        }
        .sheet(isPresented: $showProviderPicker) {
            ChatProviderListSheet(
                aiService: aiService,
                selectedProvider: viewModel.selectedProvider
            ) { provider in
                viewModel.updateProvider(provider)
                showProviderPicker = false
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showModelPicker) {
            ChatModelPickerSheet(
                models: availableModels,
                selectedModel: Binding(
                    get: { viewModel.selectedModel },
                    set: { if let m = $0 { viewModel.updateModel(m) } }
                )
            )
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var providerIcon: some View {
        if let provider = viewModel.selectedProvider,
           let iconName = provider.iconName {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }

    private var contextIndicator: some View {
        let ratio = viewModel.contextFillRatio
        let percentage = Int(ratio * 100)
        let color: Color = ratio > 0.7 ? .orange : (ratio > 0.9 ? .red : .secondary)

        return Text("\(percentage)%")
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(.capsule)
    }

    private var availableModels: [String] {
        guard let provider = viewModel.selectedProvider else { return [] }
        return aiService.getAvailableModels(for: provider)
    }
}

// MARK: - Provider List Sheet

private struct ChatProviderListSheet: View {
    let aiService: AIService
    let selectedProvider: AIProvider?
    let onSelect: (AIProvider) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if aiService.connectedProviders.contains(.apple) {
                    Section("On-Device") {
                        providerRow(for: .apple)
                    }
                }
                Section("Cloud") {
                    ForEach(cloudProviders, id: \.self) { provider in
                        providerRow(for: provider)
                    }
                }
            }
            .navigationTitle("Select Provider")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var cloudProviders: [AIProvider] {
        aiService.connectedProviders.filter { $0 != .apple }
    }

    private func providerRow(for provider: AIProvider) -> some View {
        Button {
            onSelect(provider)
            dismiss()
        } label: {
            HStack {
                if let iconName = provider.iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                Text(provider.displayName)
                Spacer()
                if selectedProvider == provider {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .tint(.primary)
    }
}

// MARK: - Model Picker Sheet

private struct ChatModelPickerSheet: View {
    let models: [String]
    @Binding var selectedModel: String?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredModels: [String] {
        if searchText.isEmpty { return models }
        return models.filter { $0.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredModels, id: \.self) { model in
                Button {
                    selectedModel = model
                    dismiss()
                } label: {
                    HStack {
                        Text(model)
                        Spacer()
                        if selectedModel == model {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .tint(.primary)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search models")
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
