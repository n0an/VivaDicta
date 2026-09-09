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

    // MARK: Whisper special / timestamp tokens

    /// Regression: 3.10.0 switched the WhisperKit transcript from
    /// `TranscriptionResult.text` (hard-filtered) to per-segment text (gated on
    /// `skipSpecialTokens`, which WhisperKit defaults to false), so users saw
    /// raw token markup. The decoder flag is the real fix; this is the net.
    @Test func filter_whisperSpecialTokens_stripped() {
        let sut = TranscriptionOutputFilter.filter(
            "<|startoftranscript|><|ru|><|transcribe|><|2.88|> Тестирую раз, два, три.<|4.80|><|endoftext|>",
            language: "ru",
            removeFillers: false
        )

        #expect(sut == "Тестирую раз, два, три.")
    }

    @Test(arguments: [
        "<|startoftranscript|>",
        "<|en|>",
        "<|transcribe|>",
        "<|translate|>",
        "<|nospeech|>",
        "<|notimestamps|>",
        "<|endoftext|>",
        "<|0.00|>",
        "<|29.98|>"
    ])
    func filter_individualWhisperToken_stripped(_ token: String) {
        let sut = TranscriptionOutputFilter.filter(
            "\(token) Hello there.",
            language: "en",
            removeFillers: false
        )

        #expect(sut == "Hello there.", "expected \(token) to be stripped, got \(sut)")
    }

    /// Multi-segment recordings leak timestamps between sentences rather than a
    /// full `sot` prefix, so the mid-string case needs covering too.
    @Test func filter_timestampTokensBetweenSegments_leaveSpeechJoined() {
        let sut = TranscriptionOutputFilter.filter(
            "<|0.00|> First sentence.<|3.80|><|3.80|> Second sentence.<|7.20|>",
            language: "en",
            removeFillers: false
        )

        #expect(sut == "First sentence. Second sentence.")
    }

    /// The pattern must not eat ordinary dictated text that happens to contain
    /// a pipe or an angle bracket.
    @Test func filter_pipesAndAnglesInRealSpeech_unchanged() {
        let input = "Run a < b and pipe it with cat | grep foo"
        let sut = TranscriptionOutputFilter.filter(input, language: "en", removeFillers: false)

        #expect(sut == input)
    }
}
