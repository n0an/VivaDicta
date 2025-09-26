//
//  TemplateSectionView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.16
//

import SwiftUI

struct TemplateSelectionView: View {
    @Binding var selectedTemplate: PromptsTemplates?
    @Binding var isPresented: Bool
    
    var body: some View {
        List(PromptsTemplates.allCases) { template in
            Button(action: {
                selectedTemplate = template
                isPresented = false
            }) {
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
            .buttonStyle(PlainButtonStyle())
        }
    }
}
