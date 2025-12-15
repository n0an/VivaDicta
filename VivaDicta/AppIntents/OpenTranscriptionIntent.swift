//
//  OpenTranscriptionIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.15
//

import AppIntents
import SwiftUI

struct OpenTranscriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note"

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
