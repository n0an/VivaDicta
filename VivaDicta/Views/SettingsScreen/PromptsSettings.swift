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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Prompts list
                if appState.promptsManager.userPrompts.isEmpty {
                    emptyStateView
                } else {
                    promptsList
                }
                
                // Add Prompt button
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
                PromptEditView(
                    template: template,
                    promptsManager: appState.promptsManager,
                    isPresented: Binding(
                        get: { selectedTemplate != nil },
                        set: { if !$0 { selectedTemplate = nil } }
                    )
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Prompts Created")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Create your first prompt from a template to get started with AI enhancement")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var promptsList: some View {
        List {
            ForEach(appState.promptsManager.userPrompts) { prompt in
                PromptRowView(
                    prompt: prompt,
                    isActive: appState.promptsManager.activePrompt?.id == prompt.id,
                    onActivate: {
                        appState.promptsManager.setActivePrompt(prompt)
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        appState.promptsManager.deletePrompt(prompt)
                    }
                    
                    Button("Edit") {
                        // TODO: Implement edit functionality
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(PlainListStyle())
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
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

struct PromptRowView: View {
    let prompt: UserPrompt
    let isActive: Bool
    let onActivate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(prompt.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if isActive {
                        Text("Active")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    
                    Text(prompt.templateType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isActive {
                onActivate()
            }
        }
    }
}

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

struct PromptEditView: View {
    let template: PromptsTemplates
    let promptsManager: PromptsManager
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var promptInstructions: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Prompt Details")) {
                    TextField("Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Prompt Instructions")) {
                    TextEditor(text: $promptInstructions)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Section(header: Text("Template")) {
                    HStack {
                        Text("Based on:")
                        Spacer()
                        Text(template.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let prompt = promptsManager.createPromptFromTemplate(
                            template,
                            title: title,
                            description: description
                        )
                        
                        var finalPrompt = prompt
                        if !promptInstructions.isEmpty {
                            finalPrompt = UserPrompt(
                                title: finalPrompt.title,
                                description: finalPrompt.description,
                                promptInstructions: promptInstructions,
                                templateType: finalPrompt.templateType
                            )
                        }
                        
                        promptsManager.addPrompt(finalPrompt)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            title = template.defaultTitle
            description = template.description
            promptInstructions = template.prompt
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    PromptsSettings(appState: appState)
}
