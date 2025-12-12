//
//  PromptEditingView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.16
//

import SwiftUI

struct PromptEditView: View {
    @Environment(\.dismiss) var dismiss
    let editingPrompt: UserPrompt?
    let promptsManager: PromptsManager

    @State private var title: String = ""
    @State private var promptInstructions: String = ""
    @State private var showInstructionsEditor = false
    @State private var showingAlert = false
    @State private var promptError: SettingsError = .duplicatePromptName("")

    init(editingPrompt: UserPrompt? = nil,
         promptsManager: PromptsManager) {
        self.editingPrompt = editingPrompt
        self.promptsManager = promptsManager
    }

    private func savePrompt() {
        guard let existingPrompt = editingPrompt else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for duplicate names (excluding current prompt)
        let otherPrompts = promptsManager.userPrompts.filter { $0.id != existingPrompt.id }
        if otherPrompts.contains(where: { $0.title.lowercased() == trimmedTitle.lowercased() }) {
            promptError = .duplicatePromptName(trimmedTitle)
            showingAlert = true
            return
        }

        let updatedPrompt = UserPrompt(
            id: existingPrompt.id,
            title: trimmedTitle,
            promptInstructions: promptInstructions,
            createdAt: existingPrompt.createdAt
        )
        promptsManager.updatePrompt(updatedPrompt)
        dismiss()
    }
    
    var body: some View {
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
        .navigationTitle("Edit Prompt")
        .toolbarTitleDisplayMode(.inline)
        
        
        .toolbar {
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
        
        .onAppear {
            if let existingPrompt = editingPrompt {
                // Pre-fill with existing prompt data
                title = existingPrompt.title
                promptInstructions = existingPrompt.promptInstructions
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
