//
//  PromptAddView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 16.09.2025.
//

import SwiftUI

struct PromptAddView: View {
    let templateToCreateNewPrompt: PromptsTemplates?
    let editingPrompt: UserPrompt?
    let promptsManager: PromptsManager
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var promptInstructions: String = ""
    
    private var isEditing: Bool {
        editingPrompt != nil
    }
    
    private var currentTemplate: PromptsTemplates {
        return templateToCreateNewPrompt ?? .regular
    }
    
    init(template: PromptsTemplates? = nil,
         editingPrompt: UserPrompt? = nil,
         promptsManager: PromptsManager,
         isPresented: Binding<Bool>) {
        self.templateToCreateNewPrompt = template
        self.editingPrompt = editingPrompt
        self.promptsManager = promptsManager
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Prompt Details")) {
                    TextField("Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Prompt Instructions")) {
                    TextEditor(text: $promptInstructions)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Section(header: Text("Template")) {
                    HStack {
                        Text("Based on:")
                        Spacer()
                        Text(currentTemplate.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Prompt" : "New Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if isEditing, let existingPrompt = editingPrompt {
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
                        } else {
                            // Create new prompt
                            let prompt = promptsManager.createPromptFromTemplate(
                                currentTemplate,
                                title: title,
                                description: description
                            )
                            
                            var finalPrompt = prompt
                            if !promptInstructions.isEmpty {
                                finalPrompt = UserPrompt(
                                    title: finalPrompt.title,
                                    description: finalPrompt.description,
                                    promptInstructions: promptInstructions,
                                    templateType: finalPrompt.templateType
                                )
                            }
                            
                            promptsManager.addPrompt(finalPrompt)
                        }
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            if isEditing, let existingPrompt = editingPrompt {
                // Pre-fill with existing prompt data
                title = existingPrompt.title
                description = existingPrompt.description
                promptInstructions = existingPrompt.promptInstructions
            } else {
                // Pre-fill with template data
                title = currentTemplate.defaultTitle
                description = currentTemplate.description
                promptInstructions = currentTemplate.prompt
            }
        }
    }
}
