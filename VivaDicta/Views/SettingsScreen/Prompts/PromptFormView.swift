//
//  PromptFormView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.16
//

import SwiftUI
import TipKit

/// Unified view for creating and editing prompts
struct PromptFormView: View {
    @Environment(\.dismiss) var dismiss

    let promptsManager: PromptsManager
    let transcriptTagsTip = TranscriptTagsTip()

    // For creating new prompts from template
    private let template: PromptsTemplates?

    // For editing existing prompts
    private let editingPrompt: UserPrompt?

    // AIService to sync prompt changes with modes (only needed when editing)
    private let aiService: AIService?

    // Callback when prompt is saved (used when presented as sheet)
    private let onComplete: (() -> Void)?

    // User's name for email template (replaces [Your Name] placeholder)
    private let emailUserName: String?

    @State private var title: String = ""
    @State private var promptInstructions: String = ""
    @State private var useSystemTemplate: Bool = true
    @State private var wrapInTranscriptTags: Bool = true
    @State private var showInstructionsEditor = false
    @State private var showingAlert = false
    @State private var promptError: SettingsError = .duplicatePromptName("")
    @State private var showDeleteConfirmation = false

    private var isEditMode: Bool {
        editingPrompt != nil
    }

    private var navigationTitle: String {
        if isEditMode {
            return "Edit Prompt"
        } else {
            let templateName = template?.displayName ?? "Custom"
            return "New \(templateName) Prompt"
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Initializers

    /// Create a new prompt from a template
    init(template: PromptsTemplates?,
         promptsManager: PromptsManager,
         emailUserName: String? = nil,
         onComplete: (() -> Void)? = nil) {
        self.template = template
        self.editingPrompt = nil
        self.aiService = nil
        self.promptsManager = promptsManager
        self.emailUserName = emailUserName
        self.onComplete = onComplete
    }

    /// Edit an existing prompt
    init(editingPrompt: UserPrompt,
         promptsManager: PromptsManager,
         aiService: AIService) {
        self.template = nil
        self.editingPrompt = editingPrompt
        self.aiService = aiService
        self.promptsManager = promptsManager
        self.emailUserName = nil
        self.onComplete = nil
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section(header: Text("Prompt Name")) {
                TextField("Title", text: $title)
            }

            Section(
                header: Text("Prompt Instructions"),
                footer: template == .custom ? Text("Tip: Use <TRANSCRIPT> to reference the transcribed text.\nExample: \"Clean up <TRANSCRIPT> and fix grammar\"") : nil
            ) {
                Button {
                    showInstructionsEditor = true
                } label: {
                    Text(promptInstructions.isEmpty ? "Tap to add instructions" : promptInstructions)
                        .lineLimit(3)
                        .foregroundStyle(promptInstructions.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit prompt instructions")
                .accessibilityHint(promptInstructions.isEmpty ? "Double tap to add instructions" : "Current instructions: \(promptInstructions)")

                TipView(transcriptTagsTip)
            }

            Section {
                DisclosureGroup("Advanced Settings") {
                    Toggle("Use System Instructions", isOn: $useSystemTemplate)

                    Text("When enabled, your instructions are combined with system instructions to improve transcription quality. Disable for full control over the AI prompt. Note: Spelling Corrections are always included when enabled in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Toggle("Wrap in <TRANSCRIPT>", isOn: $wrapInTranscriptTags)

                    Text("When enabled, the transcribed text is wrapped in <TRANSCRIPT> tags before being sent to the AI. Keep this on when using our prompt templates, as they reference the text using these tags.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isEditMode {
                if isFormValid {
                    Section {
                        
                        Button {
                            duplicatePrompt()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Duplicate Prompt", systemImage: "doc.on.doc")
                                Spacer()
                            }
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        deletePrompt()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Prompt", systemImage: "trash")
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
            }
            
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(navigationTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !isEditMode {
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
            ToolbarItem(placement: .topBarTrailing) {
                if #available(iOS 26, *) {
                    Button(role: .confirm) {
                        savePrompt()
                    }
                    .disabled(!isFormValid)
                    .tint(.blue)
                } else {
                    Button("Save") {
                        savePrompt()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            setupInitialValues()
            Task {
                await TranscriptTagsTip.promptEditOpenedEvent.donate()
            }
        }
        .fullScreenCover(isPresented: $showInstructionsEditor) {
            NavigationStack {
                PromptInstructionsEditorView(instructions: $promptInstructions)
            }
        }
        .alert(isPresented: $showingAlert,
               error: promptError,
               actions: { _ in },
               message: { error in
            Text(error.failureReason)
        })
        .alert("Delete Prompt?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePrompt()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Private Methods

    private func setupInitialValues() {
        if let existingPrompt = editingPrompt {
            // Edit mode: pre-fill with existing prompt data
            title = existingPrompt.title
            promptInstructions = existingPrompt.promptInstructions
            useSystemTemplate = existingPrompt.useSystemTemplate
            wrapInTranscriptTags = existingPrompt.wrapInTranscriptTags
        } else if let template = template, template != .custom {
            // Create mode with template: pre-fill from template
            title = template.defaultTitle
            var instructions = template.prompt

            // For email template, replace [Your Name] with user's name if provided
            if template == .email,
               let userName = emailUserName,
               !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                instructions = instructions.replacing("[Your Name]", with: userName)
            }

            promptInstructions = instructions
        }
        // Create mode without template or custom: leave empty
    }

    private func savePrompt() {
        HapticManager.lightImpact()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if isEditMode {
            saveExistingPrompt(trimmedTitle: trimmedTitle)
        } else {
            saveNewPrompt(trimmedTitle: trimmedTitle)
        }
    }

    private func saveNewPrompt(trimmedTitle: String) {
        if promptsManager.isPromptNameDuplicate(trimmedTitle) {
            promptError = .duplicatePromptName(trimmedTitle)
            showingAlert = true
            return
        }

        let prompt = UserPrompt(
            title: trimmedTitle,
            promptInstructions: promptInstructions,
            useSystemTemplate: useSystemTemplate,
            wrapInTranscriptTags: wrapInTranscriptTags
        )

        promptsManager.addPrompt(prompt)
        dismissAndComplete()
    }

    private func saveExistingPrompt(trimmedTitle: String) {
        guard let existingPrompt = editingPrompt else { return }

        if promptsManager.isPromptNameDuplicate(trimmedTitle, excludingId: existingPrompt.id) {
            promptError = .duplicatePromptName(trimmedTitle)
            showingAlert = true
            return
        }

        let updatedPrompt = UserPrompt(
            id: existingPrompt.id,
            title: trimmedTitle,
            promptInstructions: promptInstructions,
            useSystemTemplate: useSystemTemplate,
            wrapInTranscriptTags: wrapInTranscriptTags,
            createdAt: existingPrompt.createdAt
        )

        promptsManager.updatePrompt(updatedPrompt)

        // Sync the updated prompt to all modes that use it
        aiService?.updateModesWithPrompt(updatedPrompt)

        dismiss()
    }

    private func dismissAndComplete() {
        dismiss()
        onComplete?()
    }

    private func duplicatePrompt() {
        guard let existingPrompt = editingPrompt else { return }
        HapticManager.lightImpact()
        promptsManager.duplicatePrompt(existingPrompt)
        dismiss()
    }

    private func deletePrompt() {
        guard let existingPrompt = editingPrompt else { return }
        HapticManager.lightImpact()
        promptsManager.deletePrompt(existingPrompt)
        dismiss()
    }
}
