//
//  LiveTranslationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.28
//

import SwiftData
import SwiftUI

struct LiveTranslationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var service = LiveTranslationService()
    @State private var savedSnapshot: SavedSnapshot?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                languageBar
                Divider()
                transcriptColumns
                Divider()
                ttsBar
                actionBar
            }
            .navigationTitle("Live Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await service.stop()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .alert(item: failureBinding) { failure in
                Alert(
                    title: Text("Live Translation Error"),
                    message: Text(failure.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Saved", isPresented: savedAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The transcript was saved as a note.")
            }
        }
    }

    // MARK: - Subviews

    private var languageBar: some View {
        HStack(spacing: 12) {
            languageMenu(
                title: "From",
                selection: Binding(
                    get: { service.config.sourceLanguage },
                    set: { service.config.sourceLanguage = $0 }
                )
            )

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            languageMenu(
                title: "To",
                selection: Binding(
                    get: { service.config.targetLanguage },
                    set: { service.config.targetLanguage = $0 }
                )
            )

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .disabled(isRunning)
    }

    private var transcriptColumns: some View {
        HStack(spacing: 0) {
            TranscriptColumn(
                title: service.config.sourceLanguage.displayName,
                tokens: service.originalTokens,
                accent: .secondary
            )
            Divider()
            TranscriptColumn(
                title: service.config.targetLanguage.displayName,
                tokens: service.translatedTokens,
                accent: .indigo
            )
        }
    }

    private var ttsBar: some View {
        HStack {
            Image(systemName: service.config.ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .foregroundStyle(service.config.ttsEnabled ? .indigo : .secondary)
            Toggle("Speak translation", isOn: Binding(
                get: { service.config.ttsEnabled },
                set: { service.config.ttsEnabled = $0 }
            ))
            .labelsHidden()
            Text("Speak translation")
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 12) {
            if isRunning {
                Button {
                    Task { await service.stop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button {
                    Task { await service.start() }
                } label: {
                    Label("Start listening", systemImage: "waveform.and.mic")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.large)
                .disabled(service.status == .starting)
            }

            if shouldShowSaveButton {
                Button {
                    saveAsNote()
                } label: {
                    Label("Save as note", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func languageMenu(title: String, selection: Binding<LiveTranslationLanguage>) -> some View {
        Menu {
            ForEach(LiveTranslationLanguage.allCases) { language in
                Button {
                    selection.wrappedValue = language
                } label: {
                    if language == selection.wrappedValue {
                        Label(language.displayName, systemImage: "checkmark")
                    } else {
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selection.wrappedValue.displayName)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.fill.tertiary, in: .capsule)
        }
    }

    private var isRunning: Bool {
        service.status == .running || service.status == .starting
    }

    private var shouldShowSaveButton: Bool {
        guard !isRunning else { return false }
        return !service.originalTokens.isEmpty || !service.translatedTokens.isEmpty
    }

    private var failureBinding: Binding<FailureAlert?> {
        Binding(
            get: {
                if case .failed(let message) = service.status {
                    return FailureAlert(message: message)
                }
                return nil
            },
            set: { _ in
                Task { await service.stop() }
            }
        )
    }

    private var savedAlertBinding: Binding<Bool> {
        Binding(
            get: { savedSnapshot != nil },
            set: { if !$0 { savedSnapshot = nil } }
        )
    }

    private func saveAsNote() {
        let snapshot = service.transcriptSnapshot()
        guard !snapshot.original.isEmpty || !snapshot.translation.isEmpty else { return }

        let transcription = Transcription(
            text: snapshot.original.isEmpty ? snapshot.translation : snapshot.original,
            enhancedText: snapshot.translation.isEmpty ? nil : snapshot.translation,
            audioDuration: 0,
            transcriptionModelName: "stt-rt-v4",
            transcriptionProviderName: TranscriptionModelProvider.soniox.rawValue,
            sourceTag: SourceTag.liveTranslation
        )

        modelContext.insert(transcription)
        try? modelContext.save()
        savedSnapshot = SavedSnapshot()
    }

    private struct FailureAlert: Identifiable {
        let id = UUID()
        let message: String
    }

    private struct SavedSnapshot {
        let id = UUID()
    }
}

private struct TranscriptColumn: View {
    let title: String
    let tokens: [LiveTranslationToken]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(renderedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .id(scrollAnchor)
                }
                .onChange(of: tokens.count) { _, _ in
                    withAnimation { proxy.scrollTo(scrollAnchor, anchor: .bottom) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var renderedText: AttributedString {
        var attributed = AttributedString()
        for token in tokens {
            var part = AttributedString(token.text)
            if !token.isFinal {
                part.foregroundColor = .secondary
            }
            attributed.append(part)
        }
        return attributed
    }

    private let scrollAnchor = "transcriptBottom"
}
