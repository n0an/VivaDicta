// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
@testable import CloudTranscription

struct MistralTranscriptionServiceTests {

    @Test func requestLanguage_keepsExplicitLanguageWhenDiarizationDisabled() {
        let requestLanguage = MistralTranscriptionService.requestLanguage(
            for: "en",
            diarizationEnabled: false
        )

        #expect(requestLanguage == "en")
    }

    @Test func requestLanguage_skipsExplicitLanguageWhenDiarizationEnabled() {
        let requestLanguage = MistralTranscriptionService.requestLanguage(
            for: "en",
            diarizationEnabled: true
        )

        #expect(requestLanguage == nil)
    }

    @Test func requestLanguage_treatsAutoAsNil() {
        let requestLanguage = MistralTranscriptionService.requestLanguage(
            for: "auto",
            diarizationEnabled: false
        )

        #expect(requestLanguage == nil)
    }

    @Test func requestLanguage_trimsWhitespace() {
        let requestLanguage = MistralTranscriptionService.requestLanguage(
            for: "  ",
            diarizationEnabled: false
        )

        #expect(requestLanguage == nil)
    }
}
