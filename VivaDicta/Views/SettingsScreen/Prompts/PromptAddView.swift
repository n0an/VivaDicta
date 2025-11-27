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
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var promptInstructions: String = ""
    
    private var currentTemplate: PromptsTemplates {
        return templateToCreateNewPrompt ?? .regular
    }

    private func savePrompt() {
        let prompt = UserPrompt(
            title: title,
            description: description,
            promptInstructions: promptInstructions)

        promptsManager.addPrompt(prompt)
        dismiss()
    }
    
    init(template: PromptsTemplates? = nil,
         editingPrompt: UserPrompt? = nil,
         promptsManager: PromptsManager) {
        self.templateToCreateNewPrompt = template
        self.promptsManager = promptsManager
    }
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle("New \(currentTemplate.displayName) Prompt")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if #available(iOS 26, *) {
                        Button(role: .close) {
                            dismiss()
                        }
                    } else {
                        Button("Cancel") {
                            dismiss()
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
                description = ""
                promptInstructions = ""
            } else {
                title = currentTemplate.defaultTitle
                description = currentTemplate.description
                promptInstructions = currentTemplate.prompt
            }
        }
    }
}
