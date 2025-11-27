//
//  TemplateSectionView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.16
//

import SwiftUI

struct TemplateSelectionView: View {
    var promptsManager: PromptsManager
    @State private var selectedTemplate: PromptsTemplates?

    var body: some View {
        List(PromptsTemplates.allCases) { template in
            Button {
                selectedTemplate = template
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
            PromptAddView(
                template: template,
                promptsManager: promptsManager
            )
        }
    }
}
