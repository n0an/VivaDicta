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
                    }
                    .onDelete { offsets in
                        customVocabularyService.deleteWords(at: offsets)
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

#Preview {
    NavigationStack {
        DictionaryView(dictionaryType: .dictionary)
    }
}
