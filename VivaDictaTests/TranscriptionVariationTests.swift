//
//  TranscriptionVariationTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct TranscriptionVariationTests {

    // MARK: - Initialization Tests

    @Test func init_defaultValues() {
        let variation = TranscriptionVariation()

        #expect(variation.presetId == "")
        #expect(variation.presetDisplayName == "")
        #expect(variation.text == "")
        #expect(variation.aiModelName == nil)
        #expect(variation.aiProviderName == nil)
        #expect(variation.processingDuration == nil)
        #expect(variation.aiRequestSystemMessage == nil)
        #expect(variation.aiRequestUserMessage == nil)
        #expect(variation.transcription == nil)
    }

    @Test func init_withAllProperties() {
        let date = Date()
        let variation = TranscriptionVariation(
            presetId: "regular",
            presetDisplayName: "Regular",
            text: "Processed text",
            createdAt: date,
            aiModelName: "claude-sonnet-4-5",
            aiProviderName: "Anthropic",
            processingDuration: 1.5,
            aiRequestSystemMessage: "System message",
            aiRequestUserMessage: "User message"
        )

        #expect(variation.presetId == "regular")
        #expect(variation.presetDisplayName == "Regular")
        #expect(variation.text == "Processed text")
        #expect(variation.createdAt == date)
        #expect(variation.aiModelName == "claude-sonnet-4-5")
        #expect(variation.aiProviderName == "Anthropic")
        #expect(variation.processingDuration == 1.5)
        #expect(variation.aiRequestSystemMessage == "System message")
        #expect(variation.aiRequestUserMessage == "User message")
    }

    @Test func init_generatesUniqueIds() {
        let variation1 = TranscriptionVariation()
        let variation2 = TranscriptionVariation()

        #expect(variation1.id != variation2.id)
    }

    @Test func init_setsCreatedAtToNow() {
        let before = Date()
        let variation = TranscriptionVariation()
        let after = Date()

        #expect(variation.createdAt >= before)
        #expect(variation.createdAt <= after)
    }

    // MARK: - Optional Properties Tests

    @Test func optionalProperties_canBeSetToNil() {
        let variation = TranscriptionVariation(
            aiModelName: "gpt-4",
            aiProviderName: "OpenAI",
            processingDuration: 2.0
        )

        #expect(variation.aiModelName == "gpt-4")
        #expect(variation.aiProviderName == "OpenAI")
        #expect(variation.processingDuration == 2.0)

        variation.aiModelName = nil
        variation.aiProviderName = nil
        variation.processingDuration = nil

        #expect(variation.aiModelName == nil)
        #expect(variation.aiProviderName == nil)
        #expect(variation.processingDuration == nil)
    }

    // MARK: - Preset Integration Tests

    @Test func presetId_matchesKnownPresetIds() {
        let variation = TranscriptionVariation(
            presetId: "regular",
            presetDisplayName: "Regular"
        )

        #expect(PresetCatalog.builtInIds.contains(variation.presetId))
    }

    @Test func customPresetId_usesCustomPrefix() {
        let customId = "custom_\(UUID().uuidString)"
        let variation = TranscriptionVariation(
            presetId: customId,
            presetDisplayName: "My Custom Preset"
        )

        #expect(variation.presetId.hasPrefix("custom_"))
    }
}
