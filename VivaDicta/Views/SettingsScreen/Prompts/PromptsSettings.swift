//
//  PromptsSettings.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct PromptsSettings: View {
    @Bindable var appState: AppState
    @State private var showingTemplateSelection = false
    @State private var selectedTemplate: PromptsTemplates?
    @State private var editingPrompt: UserPrompt?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if appState.promptsManager.userPrompts.isEmpty {
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
                    promptsManager: appState.promptsManager,
                    isPresented: $selectedTemplate.isPresent()
                )
            }
            .sheet(item: $editingPrompt) { prompt in
                PromptEditView(
                    editingPrompt: prompt,
                    promptsManager: appState.promptsManager,
                    isPresented: $editingPrompt.isPresent()
                )
            }
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
            ForEach(appState.promptsManager.userPrompts) { prompt in
                PromptRowView(prompt: prompt)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        appState.promptsManager.deletePrompt(prompt)
                    }
                    
                    Button("Edit") {
                        editingPrompt = prompt
                    }
                    .tint(.blue)
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
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue, in: .capsule)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

struct PromptRowView: View {
    let prompt: UserPrompt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prompt.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(prompt.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}


extension Binding {
    func isPresent<T>() -> Binding<Bool> where Value == T? {
        return Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { if !$0 { self.wrappedValue = nil } }
        )
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    PromptsSettings(appState: appState)
}
