//
//  SmartSearchSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.12
//

import SwiftUI
import os

/// Settings screen for RAG Smart Search configuration.
struct SmartSearchSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SmartSearchFeature.isEnabledKey) private var isSmartSearchEnabled = true

    @State private var isReindexing = false
    @State private var service = RAGIndexingService.shared

    private let logger = Logger(category: .ragIndexing)

    var body: some View {
        Form {
            Section {
                Toggle("Enable Smart Search", isOn: $isSmartSearchEnabled)
            } footer: {
                Text("AI-powered semantic search across your notes. When disabled, Smart Search stops indexing your notes, removes the local semantic index, and hides Smart Search surfaces.")
            }

            Section {
                HStack {
                    Text("Indexed Notes")
                    Spacer()
                    if service.isIndexing || isReindexing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("\(service.indexedTranscriptionCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!isSmartSearchEnabled)

            Section {
                Button {
                    logger.logInfo("Smart Search settings requested manual reindex indexedNotes=\(service.indexedTranscriptionCount)")
                    isReindexing = true
                    Task {
                        await service.reindexAll(modelContext: modelContext)
                        logger.logInfo("Smart Search settings manual reindex finished indexedNotes=\(service.indexedTranscriptionCount)")
                        isReindexing = false
                    }
                } label: {
                    HStack {
                        Text("Re-index All Notes")
                        Spacer()
                        if isReindexing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(!isSmartSearchEnabled || isReindexing || service.isIndexing)
            } footer: {
                Text("Rebuilds the search index from scratch. Use this if search results seem incorrect.")
            }

            Section {
                Text("Smart Search uses an on-device AI model to understand your notes semantically. The model is downloaded automatically on first use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Smart Search")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isSmartSearchEnabled) { _, isEnabled in
            logger.logInfo("Smart Search settings toggled enabled=\(isEnabled) indexedNotes=\(service.indexedTranscriptionCount)")
            isReindexing = true
            Task {
                if isEnabled {
                    await service.indexAllIfNeeded(modelContext: modelContext)
                } else {
                    await service.clearAll()
                }
                logger.logInfo("Smart Search settings toggle finished enabled=\(isEnabled) indexedNotes=\(service.indexedTranscriptionCount)")
                isReindexing = false
            }
        }
    }
}
