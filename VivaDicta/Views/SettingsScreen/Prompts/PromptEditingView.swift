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
                TextEditor(text: $promptInstructions)
                    .frame(minHeight: 200)
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
    }
}
