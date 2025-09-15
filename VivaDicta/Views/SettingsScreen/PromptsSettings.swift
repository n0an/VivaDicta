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
                
                Text(prompt.templateType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
    let template: PromptsTemplates?
    let editingPrompt: UserPrompt?
    let promptsManager: PromptsManager
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var promptInstructions: String = ""
    
    private var isEditing: Bool {
        editingPrompt != nil
    }
    
    private var currentTemplate: PromptsTemplates {
        return editingPrompt?.templateType ?? template ?? .regular
    }
    
    init(template: PromptsTemplates? = nil, editingPrompt: UserPrompt? = nil, promptsManager: PromptsManager, isPresented: Binding<Bool>) {
        self.template = template
        self.editingPrompt = editingPrompt
        self.promptsManager = promptsManager
        self._isPresented = isPresented
    }
    
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
                        Text(currentTemplate.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Prompt" : "New Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if isEditing, let existingPrompt = editingPrompt {
                            // Update existing prompt
                            let updatedPrompt = UserPrompt(
                                id: existingPrompt.id,
                                title: title,
                                description: description,
                                promptInstructions: promptInstructions,
                                templateType: existingPrompt.templateType,
                                createdAt: existingPrompt.createdAt
                            )
                            promptsManager.updatePrompt(updatedPrompt)
                        } else {
                            // Create new prompt
                            let prompt = promptsManager.createPromptFromTemplate(
                                currentTemplate,
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
                        }
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            if isEditing, let existingPrompt = editingPrompt {
                // Pre-fill with existing prompt data
                title = existingPrompt.title
                description = existingPrompt.description
                promptInstructions = existingPrompt.promptInstructions
            } else {
                // Pre-fill with template data
                title = currentTemplate.defaultTitle
                description = currentTemplate.description
                promptInstructions = currentTemplate.prompt
            }
        }
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
