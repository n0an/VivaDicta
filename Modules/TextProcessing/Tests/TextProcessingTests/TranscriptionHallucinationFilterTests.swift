//
//  TranscriptionHallucinationFilterTests.swift
//  TextProcessingTests
//
//  Created by Anton Novoselov on 2026.09.06
//

import Foundation
import Testing
@testable import TextProcessing

// MARK: - Hallucination Stripping

struct TranscriptionHallucinationFilterTests {

    // MARK: Signature hallucinations (stripped anywhere)

    @Test func filter_dimaTorzokAlone_returnsEmpty() {
        let sut = TranscriptionOutputFilter.filter("Субтитры добавил DimaTorzok", language: "ru")

        #expect(sut.isEmpty)
    }

    @Test(arguments: [
        "Субтитры добавил DimaTorzok",
        "Субтитры сделал DimaTorzok",
        "Субтитры создал DimaTorzok",
        "Субтитры и перевод сделал DimaTorzok"
    ])
    func filter_dimaTorzokVerbVariants_allStripped(_ input: String) {
        let sut = TranscriptionOutputFilter.filter(input, language: "ru")

        #expect(sut.isEmpty, "expected \(input) to be stripped, got \(sut)")
    }

    /// Segments arrive space-joined on one line, so a trailing silent segment
    /// lands beside real speech rather than on its own.
    @Test func filter_dimaTorzokTrailingRealSpeech_keepsSpeech() {
        let sut = TranscriptionOutputFilter.filter(
            "Привет, как дела? Субтитры добавил DimaTorzok",
            language: "ru"
        )

        #expect(sut == "Привет, как дела?")
    }

    @Test func filter_editorCreditLine_stripped() {
        let sut = TranscriptionOutputFilter.filter(
            "Редактор субтитров А.Синецкая Корректор А.Егорова",
            language: "ru"
        )

        #expect(sut.isEmpty)
    }

    @Test func filter_turkishAndCzechSignatures_stripped() {
        #expect(TranscriptionOutputFilter.filter("Altyazı M.K.", language: "tr").isEmpty)
        #expect(TranscriptionOutputFilter.filter("Titulky vytvořil JohnyX", language: "cs").isEmpty)
    }

    // MARK: Independence from the filler toggle

    /// A filler is speech the user chose to keep; a hallucination is text they
    /// never said. The toggle governs the first, never the second.
    @Test func filter_fillerRemovalDisabled_stillStripsHallucination() {
        let sut = TranscriptionOutputFilter.filter(
            "Субтитры добавил DimaTorzok",
            language: "ru",
            removeFillers: false
        )

        #expect(sut.isEmpty)
    }

    @Test func filter_fillerRemovalDisabled_keepsFillersButDropsHallucination() {
        let sut = TranscriptionOutputFilter.filter(
            "Эм, привет. Субтитры добавил DimaTorzok",
            language: "ru",
            removeFillers: false
        )

        #expect(sut == "Эм, привет.")
    }

    // MARK: Standalone hallucinations (whole transcript only)

    @Test func filter_standalonePhraseAlone_returnsEmpty() {
        let sut = TranscriptionOutputFilter.filter("Продолжение следует...", language: "ru")

        #expect(sut.isEmpty)
    }

    @Test func filter_standalonePhraseInsideRealSpeech_isKept() {
        let input = "Мы обсудим это позже, продолжение следует в другой раз."
        let sut = TranscriptionOutputFilter.filter(input, language: "ru")

        #expect(sut == input)
    }

    @Test func filter_soundLabelAlone_returnsEmpty() {
        #expect(TranscriptionOutputFilter.filter("ВЕСЕЛАЯ МУЗЫКА", language: "ru").isEmpty)
        #expect(TranscriptionOutputFilter.filter("ЛАЙ СОБАК", language: "ru").isEmpty)
    }

    // MARK: No false positives

    @Test func filter_ordinaryRussianSpeech_unchanged() {
        let input = "Нужно добавить субтитры к этому видео завтра."
        let sut = TranscriptionOutputFilter.filter(input, language: "ru", removeFillers: false)

        #expect(sut == input)
    }

    @Test func filter_ordinaryEnglishSpeech_unchanged() {
        let input = "Thanks for watching the demo, I will send the notes over."
        let sut = TranscriptionOutputFilter.filter(input, language: "en", removeFillers: false)

        #expect(sut == input)
    }
}
