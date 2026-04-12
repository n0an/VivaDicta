//
//  SmartSearchLexicalSupport.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.12
//

import Foundation

enum SmartSearchLexicalSupport {
    static func queryTerms(from query: String) -> Set<String> {
        tokenSet(from: query).subtracting(stopWords)
    }

    static func tokenSet(from text: String) -> Set<String> {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }

        let rawTokens = String(normalized)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 }

        var tokens: Set<String> = []
        tokens.reserveCapacity(rawTokens.count * 2)

        for token in rawTokens {
            let lowered = token.lowercased()
            tokens.insert(lowered)

            if lowered.count > 4, lowered.hasSuffix("s"), !lowered.hasSuffix("ss") {
                tokens.insert(String(lowered.dropLast()))
            }
        }

        return tokens
    }

    static let stopWords: Set<String> = [
        "a", "about", "all", "am", "an", "and", "anything", "are", "as", "at",
        "be", "but", "by", "can", "did", "do", "for", "from", "hello", "hey",
        "how", "i", "if", "in", "is", "it", "its", "just", "maybe", "me",
        "mention", "mentioned", "mentions", "my", "no", "not", "of", "on", "or", "our", "please", "said", "say",
        "saying", "something", "talk", "talked", "talking", "tell", "telling", "that", "the", "their", "there", "these", "they", "this", "to",
        "told",
        "us", "was", "we", "what", "when", "where", "which", "who", "why", "with",
        "yes", "you",
        "а", "без", "был", "бы", "в", "во", "вот", "все", "где", "да", "для",
        "его", "ее", "если", "есть", "еще", "и", "из", "или", "их", "как", "ко",
        "ли", "мне", "мы", "на", "не", "нет", "но", "ну", "о", "об", "он", "она",
        "они", "оно", "от", "по", "под", "про", "с", "со", "так", "там", "то",
        "тут", "ты", "у", "уже", "привет", "здравствуй", "здравствуйте", "упоминал", "упоминала", "упоминали", "что", "это", "я",
        "говорил", "говорила", "говорили", "говорить", "может", "могу", "можем", "можешь", "быть", "сказал", "сказала", "сказали"
    ]
}
