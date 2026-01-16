//
//  PromptInstructionsEditorView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.27
//

import SwiftUI

struct PromptInstructionsEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var instructions: String
    @FocusState private var isFocused: Bool
    @State private var originalInstructions: String = ""

    var body: some View {
        TextEditor(text: $instructions)
            .focused($isFocused)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .contentMargins(.bottom, 100, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Prompt Instructions")
            .onAppear {
                originalInstructions = instructions
                isFocused = true
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if #available(iOS 26, *) {
                        Button(role: .cancel) {
                            instructions = originalInstructions
                            HapticManager.lightImpact()
                            dismiss()
                        }
                    } else {
                        Button("Cancel") {
                            instructions = originalInstructions
                            HapticManager.lightImpact()
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26, *) {
                        Button(role: .confirm) {
                            HapticManager.lightImpact()
                            dismiss()
                        }
                        .tint(.blue)
                    } else {
                        Button("Done") {
                            HapticManager.lightImpact()
                            dismiss()
                        }
                    }
                }
            }
    }
}
