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
    @State private var description: String = ""
    @State private var promptInstructions: String = ""
    
    init(editingPrompt: UserPrompt? = nil,
         promptsManager: PromptsManager) {
        self.editingPrompt = editingPrompt
        self.promptsManager = promptsManager
    }
    
    var body: some View {
            Form {
                Section(header: Text("Prompt Details")) {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Prompt Instructions")) {
                    TextEditor(text: $promptInstructions)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("Edit Prompt")
            .toolbarTitleDisplayMode(.inline)
            
            
            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    if #available(iOS 26, *) {
//                        Button(role: .close) {
//                            dismiss()
//                        }
//                    } else {
//                        Button("Cancel") {
//                            dismiss()
//                        }
//                    }
//                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26, *){
                        Button(role: .confirm) {
                            if let existingPrompt = editingPrompt {
                                // Update existing prompt
                                let updatedPrompt = UserPrompt(
                                    id: existingPrompt.id,
                                    title: title,
                                    description: description,
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
                                    description: description,
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
                description = existingPrompt.description
                promptInstructions = existingPrompt.promptInstructions
            }
        }
    }
}
