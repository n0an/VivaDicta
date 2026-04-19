//
//  OpenAskAIIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.19
//

import AppIntents

struct OpenAskAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask AI"
    static let description = IntentDescription(
        "Opens VivaDicta and shows the Ask AI chats screen.",
        categoryName: "Navigation",
        searchKeywords: ["ask", "ai", "chat", "assistant", "notes"]
    )

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
#if !os(macOS)
        await PendingAppIntentAction.shared.enqueue(.askAI)
#endif
        return .result()
    }
}
