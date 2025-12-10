//
//  DictionaryView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.10
//

import SwiftUI

struct DictionaryView: View {

    enum DictionaryType: String, CaseIterable, Identifiable {
        var id: Self { self }
        case dictionary = "Dictionary"
        case replacements = "Replacements"
    }

    @State var dictionaryType: DictionaryType = .dictionary
    @State private var newWord: String = ""
    @State private var customVocabularyService = CustomVocabularyService()
    @State private var wordToEdit: EditableWord?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Dictionary Type", selection: $dictionaryType) {
                ForEach(DictionaryType.allCases) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)

            if dictionaryType == .dictionary {
                dictionaryContent
            } else {
                replacementsContent
            }
        }
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $wordToEdit) { item in
            EditVocabularySheet(wordToEdit: item) { editedWord in
                customVocabularyService.updateWord(item.word, to: editedWord)
                wordToEdit = nil
            }
            .presentationDetents([.height(220)])
        }
    }

    private var dictionaryContent: some View {
        VStack(spacing: 0) {
            if customVocabularyService.words.isEmpty {
                ContentUnavailableView {
                    Label("No Words", systemImage: "text.book.closed")
                } description: {
                    Text("Add words that should be recognized correctly during transcription")
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(customVocabularyService.words, id: \.self) { word in
                        Text(word)
                            .contentShape(.rect)
                            .onTapGesture {
                                wordToEdit = EditableWord(word: word)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    customVocabularyService.deleteWord(word)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    wordToEdit = EditableWord(word: word)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
            }

            addWordBar
        }
    }

    private var replacementsContent: some View {
        ContentUnavailableView {
            Label("Coming Soon", systemImage: "arrow.left.arrow.right")
        } description: {
            Text("Word replacements will be available in a future update")
        }
    }

    private var addWordBar: some View {
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

            Button("Add", action: addWord)
                .buttonStyle(.borderedProminent)
                .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func addWord() {
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

            TextField("Word", text: $editedText)
                .focused($isTextFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(Color(.systemGray5))
                .clipShape(.rect(cornerRadius: 10))

            Button("Save changes") {
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
        DictionaryView(dictionaryType: .dictionary)
    }
}
