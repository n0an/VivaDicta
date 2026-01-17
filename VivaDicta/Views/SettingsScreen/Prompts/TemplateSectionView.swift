//
//  TemplateSectionView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.16
//

import SwiftUI

struct TemplateSelectionView: View {
    var promptsManager: PromptsManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: PromptsTemplates?
    @State private var showEmailNameAlert = false
    @State private var emailUserName = ""
    @State private var pendingEmailTemplate: PromptsTemplates?

    var body: some View {
        List(PromptsTemplates.allCases) { template in
            Button {
                if template == .email {
                    emailUserName = ""
                    pendingEmailTemplate = template
                    showEmailNameAlert = true
                } else {
                    selectedTemplate = template
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.displayName)
                        .font(.headline)

                    Text(template.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Select Template")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.visible)
        .fullScreenCover(item: $selectedTemplate) { template in
            NavigationStack {
                PromptFormView(
                    template: template,
                    promptsManager: promptsManager,
                    emailUserName: template == .email ? emailUserName : nil,
                    onComplete: {
                        dismiss()
                    }
                )
            }
        }
        .alert("Enter your full name for email prompt", isPresented: $showEmailNameAlert) {
            TextField("Full Name", text: $emailUserName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                emailUserName = ""
                selectedTemplate = pendingEmailTemplate
                pendingEmailTemplate = nil
            }
            Button("OK") {
                selectedTemplate = pendingEmailTemplate
                pendingEmailTemplate = nil
            }
        }
    }
}
