//
//  PromptEditingView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.16
//

import SwiftUI

struct PromptEditView: View {
    let editingPrompt: UserPrompt?
    let promptsManager: PromptsManager
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var promptInstructions: String = ""
    
    init(editingPrompt: UserPrompt? = nil,
         promptsManager: PromptsManager,
         isPresented: Binding<Bool>) {
        self.editingPrompt = editingPrompt
        self.promptsManager = promptsManager
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let existingPrompt = editingPrompt {
                            // Update existing prompt
                            let updatedPrompt = UserPrompt(
                                id: existingPrompt.id,
                                title: title,
                                description: description,
                                promptInstructions: promptInstructions,
                                templateType: existingPrompt.templateType,
                                createdAt: existingPrompt.createdAt
                            )
                            promptsManager.updatePrompt(updatedPrompt)
                        }
                        isPresented = false
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
