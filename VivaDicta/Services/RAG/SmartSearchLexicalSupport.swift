//
//  SmartSearchLexicalSupport.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.12
//

import Foundation

enum SmartSearchLexicalSupport {
    // Shared experiment switch for lexical reranking.
    // Keep this disabled unless Vectura's built-in hybrid search starts missing
    // obvious exact-term matches in real usage and we have concrete eval cases
    // showing that an extra app-side overlap signal improves ranking.
    // When disabled, Smart Search uses Vectura's native ranking only.
    static let isLexicalRerankingEnabled = false

    static func queryTerms(from query: String) -> Set<String> {
        guard isLexicalRerankingEnabled else {
            return []
        }
        return tokenSet(from: query)
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
}
