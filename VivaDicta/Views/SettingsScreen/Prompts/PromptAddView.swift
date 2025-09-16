//
//  PromptAddView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.16
//

import SwiftUI

struct PromptAddView: View {
    let templateToCreateNewPrompt: PromptsTemplates?
    let promptsManager: PromptsManager
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var promptInstructions: String = ""
    
    private var currentTemplate: PromptsTemplates {
        return templateToCreateNewPrompt ?? .regular
    }
    
    init(template: PromptsTemplates? = nil,
         editingPrompt: UserPrompt? = nil,
         promptsManager: PromptsManager,
         isPresented: Binding<Bool>) {
        self.templateToCreateNewPrompt = template
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
            }
            .navigationTitle("New Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let prompt = UserPrompt(
                            title: title,
                            description: description,
                            promptInstructions: promptInstructions, templateType: currentTemplate)
                        
                        promptsManager.addPrompt(prompt)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            title = currentTemplate.defaultTitle
            description = currentTemplate.description
            promptInstructions = currentTemplate.prompt
        }
    }
}
