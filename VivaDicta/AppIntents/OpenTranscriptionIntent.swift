//
//  OpenTranscriptionIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents
import SwiftUI

struct OpenTranscriptionIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Note"

    @Dependency private var dataController: DataController
    @Dependency private var router: Router

    @Parameter
    var target: TranscriptionEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        if let transcription = try dataController.transcription(byId: target.id) {
            router.select(transcription: transcription)
        }
        return .result()
    }
}
