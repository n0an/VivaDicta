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
        NavigationView {
            List(PromptsTemplates.allCases) { template in
                Button(action: {
                    selectedTemplate = template
                    isPresented = false
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(template.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
