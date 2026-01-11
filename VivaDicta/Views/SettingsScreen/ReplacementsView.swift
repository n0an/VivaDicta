//
//  ReplacementsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.10
//

import SwiftUI

struct ReplacementsView: View {
    @State private var originalText: String = ""
    @State private var replacementText: String = ""
    @State private var replacementsService = ReplacementsService()
    @State private var replacementToEdit: Replacement?

    @State private var editMode = false
    @State private var selectedReplacements: Set<Replacement> = []

    @AppStorage(UserDefaultsStorage.Keys.isReplacementsEnabled)
    private var isReplacementsEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            enableToggle

            if replacementsService.replacements.isEmpty {
                emptyStateView
            } else {
                if editMode {
                    editModeToolbar
                }
                replacementsList
            }

            if !editMode {
                addReplacementBar
            }
        }
        .toolbar {
            if editMode {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedReplacements.removeAll()
                        editMode = false
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        editMode = true
                    }
                    .disabled(replacementsService.replacements.isEmpty)
                }
            }
        }
        .navigationTitle("Word Replacements")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $replacementToEdit) { item in
            EditReplacementSheet(replacementToEdit: item) { newOriginal, newReplacement in
                replacementsService.updateReplacement(item, original: newOriginal, replacement: newReplacement)
                replacementToEdit = nil
            }
            .presentationDetents([.height(280)])
        }
    }

    private var enableToggle: some View {
        Toggle("Enable Replacements", isOn: $isReplacementsEnabled)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: isReplacementsEnabled) { _, _ in
                HapticManager.selectionChanged()
            }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Replacements", systemImage: "arrow.left.arrow.right")
        } description: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add text replacements that will be applied during transcription")
                Text("""
                    For example:
                        "My website link" -> "https://vivadicta.com"
                        "Vivo dicte" -> "VivaDicta"
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
        }
        .frame(maxHeight: .infinity)
    }

    private var editModeToolbar: some View {
        HStack {
            Button(allReplacementsSelected ? "Deselect All" : "Select All") {
                if allReplacementsSelected {
                    selectedReplacements.removeAll()
                } else {
                    selectedReplacements = Set(replacementsService.replacements)
                }
            }

            Spacer()

            if !selectedReplacements.isEmpty {
                Button("Delete", role: .destructive) {
                    deleteSelectedReplacements()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var allReplacementsSelected: Bool {
        !replacementsService.replacements.isEmpty &&
        selectedReplacements.count == replacementsService.replacements.count
    }

    private var replacementsList: some View {
        List {
            ForEach(replacementsService.replacements) { replacement in
                Button {
                    if editMode {
                        toggleSelection(replacement)
                    } else {
                        replacementToEdit = replacement
                    }
                } label: {
                    HStack {
                        if editMode {
                            Image(systemName: selectedReplacements.contains(replacement) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedReplacements.contains(replacement) ? .blue : .secondary)
                                .font(.title2)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(replacement.original)
                                .font(.body)
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(replacement.replacement)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !editMode {
                        Button(role: .destructive) {
                            HapticManager.warning()
                            replacementsService.deleteReplacement(replacement)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            replacementToEdit = replacement
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func toggleSelection(_ replacement: Replacement) {
        if selectedReplacements.contains(replacement) {
            selectedReplacements.remove(replacement)
        } else {
            selectedReplacements.insert(replacement)
        }
    }

    private func deleteSelectedReplacements() {
        HapticManager.warning()
        for replacement in selectedReplacements {
            replacementsService.deleteReplacement(replacement)
        }
        selectedReplacements.removeAll()

        if replacementsService.replacements.isEmpty {
            editMode = false
        }
    }

    private var addReplacementBar: some View {
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                TextField("Original text", text: $originalText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(8)
                    .background {
                        Capsule()
                            .stroke(.gray, lineWidth: 0.5)
                    }
                    .onChange(of: originalText) { _, newValue in
                        if newValue.count > ReplacementsService.maxTextLength {
                            originalText = String(newValue.prefix(ReplacementsService.maxTextLength))
                        }
                    }

                if originalText.count > 0 {
                    HStack {
                        Spacer()
                        Text("\(originalText.count)/\(ReplacementsService.maxTextLength)")
                            .font(.caption)
                            .foregroundStyle(originalText.count >= ReplacementsService.maxTextLength ? .orange : .secondary)
                    }
                }
            }

            VStack(spacing: 4) {
                TextField("Replace with", text: $replacementText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(8)
                    .background {
                        Capsule()
                            .stroke(.gray, lineWidth: 0.5)
                    }
                    .onSubmit {
                        addReplacement()
                    }
                    .onChange(of: replacementText) { _, newValue in
                        if newValue.count > ReplacementsService.maxTextLength {
                            replacementText = String(newValue.prefix(ReplacementsService.maxTextLength))
                        }
                    }

                if replacementText.count > 0 {
                    HStack {
                        Spacer()
                        Text("\(replacementText.count)/\(ReplacementsService.maxTextLength)")
                            .font(.caption)
                            .foregroundStyle(replacementText.count >= ReplacementsService.maxTextLength ? .orange : .secondary)
                    }
                }
            }

            Button("Add Replacement", action: addReplacement)
                .buttonStyle(.borderedProminent)
                .disabled(!canAddReplacement)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var canAddReplacement: Bool {
        !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addReplacement() {
        HapticManager.success()
        replacementsService.addReplacement(original: originalText, replacement: replacementText)
        originalText = ""
        replacementText = ""
    }
}

// MARK: - Edit Replacement Sheet

private struct EditReplacementSheet: View {
    let replacementToEdit: Replacement
    let onSave: (String, String) -> Void

    @State private var editedOriginal: String
    @State private var editedReplacement: String
    @FocusState private var focusedField: Field?

    enum Field {
        case original, replacement
    }

    init(replacementToEdit: Replacement, onSave: @escaping (String, String) -> Void) {
        self.replacementToEdit = replacementToEdit
        self.onSave = onSave
        self._editedOriginal = State(initialValue: replacementToEdit.original)
        self._editedReplacement = State(initialValue: replacementToEdit.replacement)
    }

    private var hasChanges: Bool {
        let trimmedOriginal = editedOriginal.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = editedReplacement.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedOriginal.isEmpty &&
               !trimmedReplacement.isEmpty &&
               (trimmedOriginal != replacementToEdit.original || trimmedReplacement != replacementToEdit.replacement)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Replacement")
                .font(.headline)

            VStack(alignment: .trailing, spacing: 4) {
                TextField("Original text", text: $editedOriginal)
                    .focused($focusedField, equals: .original)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(.systemGray5), in: .rect(cornerRadius: 10))
                    .onChange(of: editedOriginal) { _, newValue in
                        if newValue.count > ReplacementsService.maxTextLength {
                            editedOriginal = String(newValue.prefix(ReplacementsService.maxTextLength))
                        }
                    }

                Text("\(editedOriginal.count)/\(ReplacementsService.maxTextLength)")
                    .font(.caption)
                    .foregroundStyle(editedOriginal.count >= ReplacementsService.maxTextLength ? .orange : .secondary)
            }

            VStack(alignment: .trailing, spacing: 4) {
                TextField("Replace with", text: $editedReplacement)
                    .focused($focusedField, equals: .replacement)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .clipShape(.rect(cornerRadius: 10))
                    .onChange(of: editedReplacement) { _, newValue in
                        if newValue.count > ReplacementsService.maxTextLength {
                            editedReplacement = String(newValue.prefix(ReplacementsService.maxTextLength))
                        }
                    }

                Text("\(editedReplacement.count)/\(ReplacementsService.maxTextLength)")
                    .font(.caption)
                    .foregroundStyle(editedReplacement.count >= ReplacementsService.maxTextLength ? .orange : .secondary)
            }

            Button("Save changes") {
                onSave(editedOriginal, editedReplacement)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(hasChanges ? Color.blue : Color(.systemGray4))
            .foregroundStyle(hasChanges ? .white : .secondary)
            .clipShape(.rect(cornerRadius: 10))
            .disabled(!hasChanges)
        }
        .padding()
        .presentationDragIndicator(.hidden)
        .onAppear {
            focusedField = .original
        }
    }
}

#Preview {
    NavigationStack {
        ReplacementsView()
    }
}
