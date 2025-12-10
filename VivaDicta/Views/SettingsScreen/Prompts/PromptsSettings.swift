//
//  PromptsSettings.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.15
//

import SwiftUI

struct PromptsSettings: View {
    var promptsManager: PromptsManager
//    var transition: Namespace.ID
    
    var body: some View {
        VStack(spacing: 0) {
            if promptsManager.userPrompts.isEmpty {
                emptyStateView
            } else {
                promptsList
            }
        }
        .toolbar {
            ToolbarItem {
                NavigationLink(value: SettingsDestination.promptsTemplates) {
                    Label("Add Data", systemImage: "plus")
                }
                .prominentButton(color: .blue)
            }
            
        }
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
                NavigationLink(value: prompt) {
                    PromptRowView(prompt: prompt)
                }
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
            Text(prompt.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}

#Preview {
    @Previewable @State var promptsManager = PromptsManager()
//    @Previewable @Namespace var transition
    PromptsSettings(promptsManager: promptsManager)
}
