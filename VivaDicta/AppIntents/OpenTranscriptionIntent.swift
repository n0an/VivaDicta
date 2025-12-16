//
//  OpenTranscriptionIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents
import SwiftUI

struct OpenTranscriptionSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note Snippet"

    @Parameter
    var target: TranscriptionEntity

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        return .result(
            dialog: "\(target.subtitle)"
        ) {
            VStack(alignment: .leading) {
                Image(systemName: "microphone.circle")
                    .symbolRenderingMode(.multicolor)
                    .font(.largeTitle)

                Text(target.text(withPrefix: 200))
            }
            .padding()
        }
    }
}

struct OpenTranscriptionIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Note"

    @Dependency var dataController: DataController
    
    @Parameter
    var target: TranscriptionEntity

    func perform() async throws -> some IntentResult {
        try await dataController.select(entity: target)
        return .result()
    }
}
