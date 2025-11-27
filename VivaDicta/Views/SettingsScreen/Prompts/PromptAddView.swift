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

    private var currentTemplate: PromptsTemplates {
        return templateToCreateNewPrompt ?? .regular
    }

    private func savePrompt() {
        let prompt = UserPrompt(
            title: title,
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
                Section(header: Text("Prompt Details")) {
                    TextField("Title", text: $title)
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
    }
}
