//
//  TagManagementView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionTag.sortOrder) private var tags: [TranscriptionTag]

    @State private var showCreateSheet = false
    @State private var tagToEdit: TranscriptionTag?

    var body: some View {
        List {
            if tags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag",
                    description: Text("Create tags to organize your transcriptions.")
                )
            } else {
                ForEach(tags) { tag in
                    Button {
                        tagToEdit = tag
                    } label: {
                        TagRowView(tag: tag)
                    }
                    .tint(.primary)
                }
                .onDelete(perform: deleteTags)
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Tag", systemImage: "plus") {
                    showCreateSheet = true
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            TagEditorSheet(mode: .create) { name, colorHex, icon in
                let tag = TranscriptionTag(name: name, colorHex: colorHex, icon: icon, sortOrder: tags.count)
                modelContext.insert(tag)
                try? modelContext.save()
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $tagToEdit) { tag in
            TagEditorSheet(mode: .edit(tag)) { name, colorHex, icon in
                tag.name = name
                tag.colorHex = colorHex
                tag.icon = icon
                try? modelContext.save()
            }
            .presentationDetents([.medium])
        }
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            // Delete all assignments for this tag first
            let tagId = tag.id
            let descriptor = FetchDescriptor<TranscriptionTagAssignment>(
                predicate: #Predicate { $0.tagId == tagId }
            )
            if let assignments = try? modelContext.fetch(descriptor) {
                for assignment in assignments {
                    modelContext.delete(assignment)
                }
            }
            modelContext.delete(tag)
        }
        try? modelContext.save()
    }
}

private struct TagRowView: View {
    let tag: TranscriptionTag

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tag.icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color(hex: tag.colorHex) ?? .blue)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.body)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
