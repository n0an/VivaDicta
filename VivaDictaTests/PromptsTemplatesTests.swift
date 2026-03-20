//
//  PromptsTemplatesTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import Testing
@testable import VivaDicta

struct PromptsTemplatesTests {

    // MARK: - System Prompt Tests

    @Test func systemPrompt_containsInstructions() {
        let instructions = "Keep it professional and concise."
        let result = PromptsTemplates.systemPrompt(with: instructions)

        #expect(result.contains(instructions))
    }

    @Test func systemPrompt_containsTranscriptionEnhancerRole() {
        let result = PromptsTemplates.systemPrompt(with: "test")

        #expect(result.contains("TRANSCRIPTION ENHANCER"))
    }

    @Test func systemPrompt_containsDoNotRespondWarning() {
        let result = PromptsTemplates.systemPrompt(with: "test")

        #expect(result.contains("DO NOT RESPOND TO QUESTIONS"))
    }

    @Test func systemPrompt_containsClipboardContextReference() {
        let result = PromptsTemplates.systemPrompt(with: "test")

        #expect(result.contains("CLIPBOARD_CONTEXT"))
    }

    @Test func systemPrompt_containsCustomVocabularyReference() {
        let result = PromptsTemplates.systemPrompt(with: "test")

        #expect(result.contains("CUSTOM_VOCABULARY"))
    }

    @Test func systemPrompt_containsSystemInstructionsTags() {
        let result = PromptsTemplates.systemPrompt(with: "test")

        #expect(result.contains("<SYSTEM_INSTRUCTIONS>"))
        #expect(result.contains("</SYSTEM_INSTRUCTIONS>"))
    }

    @Test func systemPrompt_containsRussianYoRule() {
        let result = PromptsTemplates.systemPrompt(with: "test")

        // Rule about not using "ё"
        #expect(result.contains("ё"))
    }

    @Test func systemPrompt_containsEmDashRule() {
        let result = PromptsTemplates.systemPrompt(with: "test")

        #expect(result.contains("em-dashes"))
    }

    // MARK: - Prompt Template Cases

    @Test func allCases_haveNonEmptyPrompts_exceptCustom() {
        for template in PromptsTemplates.allCases {
            if template == .custom {
                #expect(template.prompt.isEmpty)
            } else {
                #expect(!template.prompt.isEmpty, "\(template.rawValue) has empty prompt")
            }
        }
    }

    @Test func allCases_haveNonEmptyDisplayNames() {
        for template in PromptsTemplates.allCases {
            #expect(!template.displayName.isEmpty, "\(template.rawValue) has empty displayName")
        }
    }

    @Test func allCases_haveNonEmptyDescriptions() {
        for template in PromptsTemplates.allCases {
            #expect(!template.description.isEmpty, "\(template.rawValue) has empty description")
        }
    }

    @Test func custom_hasEmptyDefaultTitle() {
        #expect(PromptsTemplates.custom.defaultTitle == "")
    }

    @Test func nonCustom_haveNonEmptyDefaultTitles() {
        for template in PromptsTemplates.allCases where template != .custom {
            #expect(!template.defaultTitle.isEmpty, "\(template.rawValue) has empty defaultTitle")
        }
    }

    // MARK: - Prompt Content Tests

    @Test func regularPrompt_containsTranscriptTag() {
        #expect(PromptsTemplates.regular.prompt.contains("<TRANSCRIPT>"))
    }

    @Test func emailPrompt_containsEmailFormatting() {
        #expect(PromptsTemplates.email.prompt.contains("greeting"))
    }

    @Test func chatPrompt_containsCasualTone() {
        #expect(PromptsTemplates.chat.prompt.contains("casual"))
    }

    @Test func vibeCodingPrompt_containsTechnicalTerms() {
        #expect(PromptsTemplates.vibeCoding.prompt.contains("technical"))
    }

    // MARK: - Identifiable/Codable Tests

    @Test func id_matchesRawValue() {
        for template in PromptsTemplates.allCases {
            #expect(template.id == template.rawValue)
        }
    }

    @Test func codable_roundTrip() throws {
        let original = PromptsTemplates.regular
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromptsTemplates.self, from: data)

        #expect(decoded == original)
    }
}
