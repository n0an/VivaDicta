// Copyright © 2026 Anton Novoselov. All rights reserved.

import AppGroup
import CloudTranscription
import SwiftUI

/// Editor for the instruction sent alongside the audio to Gemini's
/// general-purpose models.
///
/// Only those models are prompted at all: `gemini-3.5-transcribe` goes through
/// the Interactions API, which rejects a developer instruction outright, so a
/// custom prompt has no effect when it is the selected model.
struct GeminiTranscriptionPromptView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppGroupCoordinator.kGeminiTranscriptionPrompt, store: UserDefaultsStorage.shared)
    private var storedPrompt = ""

    @State private var draft = ""
    @FocusState private var isEditorFocused: Bool

    private var defaultPrompt: String { GeminiTranscriptionService.defaultTranscriptionPrompt }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $draft)
                    .frame(minHeight: 140)
                    .focused($isEditorFocused)
                    .autocorrectionDisabled()
            } header: {
                Text("Instruction")
            } footer: {
                Text("Sent with the audio to Gemini's general-purpose models. Leave it empty to use the built-in instruction.")
            }

            Section {
                Text(defaultPrompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Reset to Default") {
                    draft = ""
                    HapticManager.lightImpact()
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Built-In Instruction")
            }

            Section {
                Label(
                    "Gemini 3.5 Transcribe ignores this - Google's dedicated transcription models do not accept an instruction.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } footer: {
                Text("A prompt that asks for anything other than a transcript - a summary, a translation - is what you will get back, and the rest of the app treats it as the transcript.")
            }
        }
        .navigationTitle("Transcription Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = storedPrompt }
        .onDisappear { save() }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    save()
                    isEditorFocused = false
                    dismiss()
                }
            }
        }
    }

    /// Blank and whitespace-only drafts are stored as empty, which is how the
    /// transcription layer is told to fall back to the built-in instruction.
    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != storedPrompt else { return }
        storedPrompt = trimmed
    }
}

#Preview {
    NavigationStack {
        GeminiTranscriptionPromptView()
    }
}
