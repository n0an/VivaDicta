// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
@testable import VivaDicta

struct LanguageScoreTests {

    @Test func sortsByProbabilityDescending() {
        let scores = LanguageScore.sorted(from: ["ru": 0.29, "en": 0.61, "uk": 0.04])
        #expect(scores.map(\.code) == ["en", "ru", "uk"])
    }

    @Test func breaksTiesAlphabetically() {
        let scores = LanguageScore.sorted(from: ["pl": 0.02, "de": 0.02, "uk": 0.02])
        #expect(scores.map(\.code) == ["de", "pl", "uk"])
    }

    @Test func emptyInputProducesEmptyOutput() {
        #expect(LanguageScore.sorted(from: [:]).isEmpty)
    }

    @Test func fallsBackToRawCodeForUnknownLanguage() {
        let score = LanguageScore(code: "zz-unknown", probability: 0.5)
        #expect(score.displayName.isEmpty == false)
    }

    @Test func formatsPercentWithOneFractionDigit() {
        let score = LanguageScore(code: "en", probability: 0.6149)
        #expect(score.formattedPercent.contains("61"))
    }
}
