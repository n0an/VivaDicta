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

    var body: some View {
        TextEditor(text: $instructions)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .contentMargins(.bottom, 100, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Prompt Instructions")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
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
