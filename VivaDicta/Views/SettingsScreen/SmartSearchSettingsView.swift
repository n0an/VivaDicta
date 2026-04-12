//
//  SmartSearchSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.12
//

import SwiftUI

/// Settings screen for RAG Smart Search configuration.
struct SmartSearchSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isReindexing = false

    private var service: RAGIndexingService { RAGIndexingService.shared }

    var body: some View {
        Form {
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

            Section {
                Button {
                    isReindexing = true
                    Task {
                        await service.reindexAll(modelContext: modelContext)
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
                .disabled(isReindexing || service.isIndexing)
            } footer: {
                Text("Rebuilds the search index from scratch. Use this if search results seem incorrect.")
            }

            Section {
                Text("Smart Search uses an on-device AI model (~16 MB) to understand your notes semantically. The model is downloaded automatically on first use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Smart Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}
