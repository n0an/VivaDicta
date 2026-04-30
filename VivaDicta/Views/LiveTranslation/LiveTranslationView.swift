//
//  LiveTranslationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.28
//

import AVFoundation
import SwiftData
import SwiftUI

struct LiveTranslationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var service = LiveTranslationService()
    @State private var savedSnapshot: SavedSnapshot?
    @State private var saveError: SaveErrorAlert?
    @State private var headphonesConnected = LiveTranslationAudio.isHeadphonesRouteActive
    @State private var hasSonioxKey: Bool = false

    private static let sonioxConsoleURL = URL(string: "https://console.soniox.com/", encodingInvalidCharacters: false)
        ?? URL(string: "https://soniox.com")!

    var body: some View {
        NavigationStack {
            Group {
                if hasSonioxKey {
                    sessionContent
                } else {
                    missingKeyEmptyState
                }
            }
            .onAppear {
                hasSonioxKey = checkSonioxKey()
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                headphonesConnected = LiveTranslationAudio.isHeadphonesRouteActive
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
            .alert(item: $saveError) { error in
                Alert(
                    title: Text("Couldn't Save Note"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    @ViewBuilder
    private var sessionContent: some View {
        VStack(spacing: 0) {
            languageBar
            Divider()
            transcriptColumns
            Divider()
            ttsBar
            actionBar
        }
    }

    private var missingKeyEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.indigo)

            VStack(spacing: 8) {
                Text("Soniox API key required")
                    .font(.title2.weight(.semibold))
                Text("Live Translation uses Soniox for real-time speech recognition and translation. Add your API key in Settings to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    appState.pendingCloudTranscriptionProvider = .soniox
                    dismiss()
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.large)

                Link(destination: Self.sonioxConsoleURL) {
                    Label("Get a Soniox key", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func checkSonioxKey() -> Bool {
        guard let key = KeychainService.shared.getString(forKey: "sonioxAPIKey") else {
            return false
        }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private var headphonesHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption)
            Text("Use headphones for clearer audio, or hold your iPhone near your ear")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 8) {
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

                if service.config.ttsEnabled {
                    voiceMenu
                }
            }

            if service.config.ttsEnabled {
                HStack(spacing: 12) {
                    Image(systemName: "tortoise.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Slider(
                        value: Binding(
                            get: { Double(service.config.ttsRate) },
                            set: { service.config.ttsRate = Float($0) }
                        ),
                        in: Double(LiveTranslationPreferences.minTTSRate)...Double(LiveTranslationPreferences.maxTTSRate),
                        step: 0.05
                    )
                    Image(systemName: "hare.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    HStack(spacing: 0) {
                        Text(Double(service.config.ttsRate), format: .number.precision(.fractionLength(2)))
                        Text("x")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
                }

                if !headphonesConnected {
                    headphonesHint
                }
            }
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

    private var voiceMenu: some View {
        // Soniox tts-rt voices are multilingual, so this is a pure timbre
        // pick - no need to gate by source/target language.
        Menu {
            Picker("Voice", selection: Binding(
                get: { LiveTranslationVoice(rawValue: service.config.ttsVoice) ?? .default },
                set: { service.config.ttsVoice = $0.rawValue }
            )) {
                ForEach(LiveTranslationVoice.allCases) { voice in
                    Text(voice.displayName).tag(voice)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.wave.2.fill")
                    .font(.caption)
                Text(service.config.ttsVoice)
                    .font(.caption.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.fill.tertiary, in: .capsule)
            .foregroundStyle(.primary)
        }
        .disabled(isRunning)
    }

    private func languageMenu(title: String, selection: Binding<LiveTranslationLanguage>) -> some View {
        let preferred = LiveTranslationLanguage.userPreferred
        let preferredSet = Set(preferred)
        let rest = LiveTranslationLanguage.alphabetical.filter { !preferredSet.contains($0) }

        // Picker nested inside Menu: the outer Menu keeps the custom chip
        // label (title caption, capsule background, chevron-down), while the
        // inner Picker drives selection state - iOS draws the checkmark in
        // its own column so flags + names stay aligned across rows.
        return Menu {
            Picker("Language", selection: selection) {
                ForEach(preferred) { language in
                    Text(language.displayNameWithFlag).tag(language)
                }
                
                

                ForEach(rest) { language in
                    Text(language.displayNameWithFlag).tag(language)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selection.wrappedValue.displayNameWithFlag)
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
            set: { newValue in
                // Clear the .failed status on dismissal; otherwise the getter
                // keeps returning a fresh FailureAlert and the alert reappears
                // immediately, trapping the user in a loop.
                if newValue == nil {
                    service.clearFailureIfNeeded()
                }
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

        // Combine source + translation into the `text` field with section
        // headings; leave `enhancedText` nil so Spotlight, list previews,
        // search, and the dual-write Variation pipeline aren't confused
        // (`enhancedText` is the AI-output cache and must not hold raw MT).
        let combined = combineSnapshot(snapshot)

        let transcription = Transcription(
            text: combined,
            audioDuration: 0,
            transcriptionModelName: "stt-rt-v4",
            transcriptionProviderName: TranscriptionModelProvider.soniox.rawValue,
            sourceTag: SourceTag.liveTranslation
        )

        modelContext.insert(transcription)

        do {
            try modelContext.save()
            savedSnapshot = SavedSnapshot()
        } catch {
            // Roll the insert out of the context so the same Transcription
            // instance isn't dangling in memory and won't auto-save next
            // time the context flushes. Keep the in-memory transcript so
            // the user can retry.
            modelContext.delete(transcription)
            saveError = SaveErrorAlert(message: error.localizedDescription)
        }
    }

    private func combineSnapshot(
        _ snapshot: (sourceLanguage: LiveTranslationLanguage, original: String, targetLanguage: LiveTranslationLanguage, translation: String)
    ) -> String {
        // Use the snapshot's session-time languages, not service.config.* —
        // the user can change pickers between Stop and Save.
        var sections: [String] = []
        if !snapshot.original.isEmpty {
            sections.append("\(snapshot.sourceLanguage.displayName):\n\(snapshot.original)")
        }
        if !snapshot.translation.isEmpty {
            sections.append("\(snapshot.targetLanguage.displayName):\n\(snapshot.translation)")
        }
        return sections.joined(separator: "\n\n")
    }

    private struct FailureAlert: Identifiable {
        let id = UUID()
        let message: String
    }

    private struct SavedSnapshot {
        let id = UUID()
    }

    private struct SaveErrorAlert: Identifiable {
        let id = UUID()
        let message: String
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
