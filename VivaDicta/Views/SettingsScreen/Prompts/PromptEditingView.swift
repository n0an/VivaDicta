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
    
    init(editingPrompt: UserPrompt? = nil,
         promptsManager: PromptsManager) {
        self.editingPrompt = editingPrompt
        self.promptsManager = promptsManager
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
        .navigationTitle("Edit Prompt")
        .toolbarTitleDisplayMode(.inline)
        
        
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if #available(iOS 26, *){
                    Button(role: .confirm) {
                        if let existingPrompt = editingPrompt {
                            // Update existing prompt
                            let updatedPrompt = UserPrompt(
                                id: existingPrompt.id,
                                title: title,
                                promptInstructions: promptInstructions,
                                createdAt: existingPrompt.createdAt
                            )
                            promptsManager.updatePrompt(updatedPrompt)
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                    .tint(.blue)
                } else {
                    Button("Save") {
                        if let existingPrompt = editingPrompt {
                            // Update existing prompt
                            let updatedPrompt = UserPrompt(
                                id: existingPrompt.id,
                                title: title,
                                promptInstructions: promptInstructions,
                                createdAt: existingPrompt.createdAt
                            )
                            promptsManager.updatePrompt(updatedPrompt)
                        }
                        dismiss()
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
    }
}
