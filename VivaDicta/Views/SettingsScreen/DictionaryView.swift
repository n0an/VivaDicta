//
//  WordsDictionaryView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.10
//

import SwiftUI

struct WordsDictionaryView: View {
    @State private var newWord: String = ""
    @State private var customVocabularyService = CustomVocabularyService()
    @State private var wordToEdit: EditableWord?

    @State private var editMode = false
    @State private var selectedWords: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            if customVocabularyService.words.isEmpty {
                emptyStateView
            } else {
                if editMode {
                    editModeToolbar
                }
                wordsList
            }

            if !editMode {
                addWordBar
            }
        }
        .toolbar {
            if editMode {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticManager.lightImpact()
                        selectedWords.removeAll()
                        editMode = false
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        HapticManager.lightImpact()
                        editMode = true
                    }
                    .disabled(customVocabularyService.words.isEmpty)
                }
            }
        }
        .navigationTitle("Spelling Corrections")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $wordToEdit) { item in
            EditVocabularySheet(wordToEdit: item) { editedWord in
                customVocabularyService.updateWord(item.word, to: editedWord)
                wordToEdit = nil
            }
            .presentationDetents([.height(180)])
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Words", systemImage: "text.book.closed")
        } description: {
            Text("Add words that should be recognized correctly during transcription")
        }
        .frame(maxHeight: .infinity)
    }

    private var editModeToolbar: some View {
        HStack {
            Button(allWordsSelected ? "Deselect All" : "Select All") {
                if allWordsSelected {
                    HapticManager.selectionChanged()
                    selectedWords.removeAll()
                } else {
                    HapticManager.selectionChanged()
                    selectedWords = customVocabularyService.words
                }
            }

            Spacer()

            if !selectedWords.isEmpty {
                Button("Delete", role: .destructive) {
                    deleteSelectedWords()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var allWordsSelected: Bool {
        !customVocabularyService.words.isEmpty && selectedWords.count == customVocabularyService.words.count
    }

    private var wordsList: some View {
        List {
            ForEach(customVocabularyService.words, id: \.self) { word in
                Button {
                    if editMode {
                        toggleSelection(word)
                    } else {
                        wordToEdit = EditableWord(word: word)
                    }
                } label: {
                    HStack {
                        if editMode {
                            Image(systemName: selectedWords.contains(word) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedWords.contains(word) ? .blue : .secondary)
                                .font(.title2)
                        }

                        Text(word)
                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !editMode {
                        Button(role: .destructive) {
                            HapticManager.mediumImpact()
                            customVocabularyService.deleteWord(word)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            HapticManager.lightImpact()
                            wordToEdit = EditableWord(word: word)
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

    private func toggleSelection(_ word: String) {
        HapticManager.selectionChanged()
        if selectedWords.contains(word) {
            selectedWords.removeAll { $0 == word }
        } else {
            selectedWords.append(word)
        }
    }

    private func deleteSelectedWords() {
        HapticManager.warning()
        for word in selectedWords {
            customVocabularyService.deleteWord(word)
        }
        selectedWords.removeAll()

        // Exit edit mode if no words left
        if customVocabularyService.words.isEmpty {
            editMode = false
        }
    }

    private var addWordBar: some View {
        VStack(spacing: 4) {
            HStack {
                TextField("Enter word", text: $newWord)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(8)
                    .background {
                        Capsule()
                            .stroke(.gray, lineWidth: 0.5)
                    }
                    .onSubmit {
                        addWord()
                    }
                    .onChange(of: newWord) { _, newValue in
                        // Limit input to max word length
                        if newValue.count > CustomVocabularyService.maxWordLength {
                            newWord = String(newValue.prefix(CustomVocabularyService.maxWordLength))
                        }
                    }

                Button("Add", action: addWord)
                    .buttonStyle(.borderedProminent)
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if newWord.count > 0 {
                HStack {
                    Spacer()
                    Text("\(newWord.count)/\(CustomVocabularyService.maxWordLength)")
                        .font(.caption)
                        .foregroundStyle(newWord.count >= CustomVocabularyService.maxWordLength ? .orange : .secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func addWord() {
        HapticManager.mediumImpact()
        customVocabularyService.addWord(newWord)
        newWord = ""
    }
}

// MARK: - Editable Word

private struct EditableWord: Identifiable {
    let id = UUID()
    let word: String
}

// MARK: - Edit Vocabulary Word Sheet

private struct EditVocabularySheet: View {
    let wordToEdit: EditableWord
    let onSave: (String) -> Void

    @State private var editedText: String
    @FocusState private var isTextFieldFocused: Bool

    init(wordToEdit: EditableWord, onSave: @escaping (String) -> Void) {
        self.wordToEdit = wordToEdit
        self.onSave = onSave
        self._editedText = State(initialValue: wordToEdit.word)
    }

    private var hasChanges: Bool {
        editedText.trimmingCharacters(in: .whitespacesAndNewlines) != wordToEdit.word &&
        !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Word")
                .font(.headline)

            VStack(alignment: .trailing, spacing: 4) {
                TextField("Word", text: $editedText)
                    .focused($isTextFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .clipShape(.rect(cornerRadius: 10))
                    .onChange(of: editedText) { _, newValue in
                        if newValue.count > CustomVocabularyService.maxWordLength {
                            editedText = String(newValue.prefix(CustomVocabularyService.maxWordLength))
                        }
                    }

                Text("\(editedText.count)/\(CustomVocabularyService.maxWordLength)")
                    .font(.caption)
                    .foregroundStyle(editedText.count >= CustomVocabularyService.maxWordLength ? .orange : .secondary)
            }

            Button("Save changes") {
                HapticManager.mediumImpact()
                onSave(editedText)
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
            isTextFieldFocused = true
        }
    }
}

#Preview {
    NavigationStack {
        WordsDictionaryView()
    }
}
