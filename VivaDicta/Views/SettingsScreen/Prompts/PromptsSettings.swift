//
//  PromptsSettings.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct PromptsSettings: View {
    var promptsManager: PromptsManager
    @State private var showingTemplateSelection = false
    @State private var selectedTemplate: PromptsTemplates?
    @State private var editingPrompt: UserPrompt?
    
    var body: some View {
        VStack(spacing: 0) {
            if promptsManager.userPrompts.isEmpty {
                emptyStateView
            } else {
                promptsList
            }
            
            addPromptSection
        }
        .navigationTitle("Prompts")
        .sheet(isPresented: $showingTemplateSelection) {
            TemplateSelectionView(
                selectedTemplate: $selectedTemplate,
                isPresented: $showingTemplateSelection
            )
        }
        .sheet(item: $selectedTemplate) { template in
            PromptAddView(
                template: template,
                promptsManager: promptsManager
            )
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditView(
                editingPrompt: prompt,
                promptsManager: promptsManager
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Prompts Created")
                .font(.title2.weight(.medium))
            
            Text("Create your first prompt from a template to get started with AI enhancement")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var promptsList: some View {
        List {
            ForEach(promptsManager.userPrompts) { prompt in
                Button(action: {
                    editingPrompt = prompt
                }) {
                    PromptRowView(prompt: prompt)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        promptsManager.deletePrompt(prompt)
                    }
                }
            }
        }
    }
    
    private var addPromptSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button(action: {
                showingTemplateSelection = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    
                    Text("Add Prompt")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue, in: .capsule)
            }
            .padding()
        }
    }
}

struct PromptRowView: View {
    let prompt: UserPrompt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if !prompt.description.isEmpty {
                    Text(prompt.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var promptsManager = PromptsManager()
    PromptsSettings(promptsManager: promptsManager)
}
