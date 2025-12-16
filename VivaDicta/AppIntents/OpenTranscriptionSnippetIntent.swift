//
//  OpenTranscriptionSnippetIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.16
//

import AppIntents
import SwiftUI

struct OpenTranscriptionSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note Snippet"
    
    @Dependency private var router: Router

    @Parameter
    var target: TranscriptionEntity

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        return .result(
            dialog: "\(target.subtitle)"
        ) {
            VStack(alignment: .center) {
                Text(target.text(withPrefix: 200))
                    .multilineTextAlignment(.leading)
                    .lineLimit(0)
            }
            .padding()
        }
    }
}

#Preview {
    @Previewable @State var target = Transcription.mockData[0].entity
    VStack(alignment: .center) {
        Text(target.text(withPrefix: 200))
            .multilineTextAlignment(.leading)
            .lineLimit(0)
    }
    .padding()
}
