//
//  PromptsSettings.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct PromptsSettings: View {
    @Namespace private var transition
    
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
        }
        .sheet(isPresented: $showingTemplateSelection) {
            NavigationStack {
                TemplateSelectionView(
                    selectedTemplate: $selectedTemplate,
                    isPresented: $showingTemplateSelection
                )
                .navigationTitle("Select Template")
                .navigationBarTitleDisplayMode(.inline)

                .scrollContentBackground(.visible)
            }
            .navigationTransition(
                .zoom(sourceID: "info", in: transition)
            )
            .presentationDetents([.medium])
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
        .toolbar {
            if #available(iOS 26, *) {
                ToolbarItem {
                    Button("Add Data", systemImage: "plus") {
                        showingTemplateSelection = true
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                }
                .matchedTransitionSource(id: "info", in: transition)
            } else {
                ToolbarItem {
                    Button("Add Data", systemImage: "plus") {
                        showingTemplateSelection = true
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: showingTemplateSelection)
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationTitle("Prompts")
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
//    private var addPromptSection: some View {
//        VStack {
//            Spacer()
//            HStack {
//                Spacer()
//                Button {
//                    showingTemplateSelection = true
//                } label: {
//                    Image(systemName: "plus.circle.fill")
//                        .font(.title2)
//                        .foregroundStyle(.white)
//                }
//                .frame(width: 60, height: 60)
//                .background(Color.blue, in: .circle)
//                .matchedTransitionSource(
//                    id: "info", in: transition
//                )
//                .padding(.trailing, 20)
//            }
//            .padding(.bottom, 20)
//        }
//    }
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
        .contentShape(.rect)
    }
}

#Preview {
    @Previewable @State var promptsManager = PromptsManager()
    PromptsSettings(promptsManager: promptsManager)
}
