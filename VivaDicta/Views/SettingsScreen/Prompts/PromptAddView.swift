//
//  PromptAddView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.16
//

import SwiftUI

struct PromptAddView: View {
    @Environment(\.dismiss) var dismiss
    let templateToCreateNewPrompt: PromptsTemplates?
    let promptsManager: PromptsManager
    var onComplete: (() -> Void)?

    @State private var title: String = ""
    @State private var promptInstructions: String = ""
    @State private var showInstructionsEditor = false
    @State private var showingAlert = false
    @State private var promptError: SettingsError = .duplicatePromptName("")

    private var currentTemplate: PromptsTemplates {
        return templateToCreateNewPrompt ?? .regular
    }

    private func savePrompt() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if promptsManager.isPromptNameDuplicate(trimmedTitle) {
            promptError = .duplicatePromptName(trimmedTitle)
            showingAlert = true
            return
        }

        let prompt = UserPrompt(
            title: trimmedTitle,
            promptInstructions: promptInstructions)

        promptsManager.addPrompt(prompt)
        dismissAndComplete()
    }

    private func dismissAndComplete() {
        dismiss()
        onComplete?()
    }

    init(template: PromptsTemplates? = nil,
         editingPrompt: UserPrompt? = nil,
         promptsManager: PromptsManager,
         onComplete: (() -> Void)? = nil) {
        self.templateToCreateNewPrompt = template
        self.promptsManager = promptsManager
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Prompt Name")) {
                    TextField("Title", text: $title)
                }

                Section(header: Text("Prompt Instructions")) {
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
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("New \(currentTemplate.displayName) Prompt")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if #available(iOS 26, *) {
                        Button(role: .close) {
                            dismissAndComplete()
                        }
                    } else {
                        Button("Cancel") {
                            dismissAndComplete()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26, *) {
                        Button(role: .confirm) {
                            savePrompt()
                        }
                        .disabled(title.isEmpty)
                        .tint(.blue)
                    } else {
                        Button("Save") {
                            savePrompt()
                        }
                        .disabled(title.isEmpty)
                    }
                }
            }
        }
        .onAppear {
            if currentTemplate == .custom {
                title = ""
                promptInstructions = ""
            } else {
                title = currentTemplate.defaultTitle
                promptInstructions = currentTemplate.prompt
            }
        }
        .sheet(isPresented: $showInstructionsEditor) {
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
    }
}
