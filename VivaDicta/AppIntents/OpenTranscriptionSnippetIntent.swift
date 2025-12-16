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
                Image(systemName: "microphone.circle")
                    .symbolRenderingMode(.multicolor)
                    .font(.largeTitle)

                Text(target.text(withPrefix: 200))
                Button {
                    
                } label: {
                    Text("Open in VivaDicta")
                        .font(.title2.weight(.semibold))
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                }
                
                .buttonStyle(.borderedProminent)
                
            }
            .padding()
        }
    }
}

#Preview {
    @Previewable @State var target = Transcription.mockData[0].entity
    VStack(alignment: .center) {
        Image(systemName: "microphone.circle")
            .symbolRenderingMode(.multicolor)
            .font(.largeTitle)

        Text(target.text(withPrefix: 200))
        Button {
            
        } label: {
            Text("Open in VivaDicta")
                .font(.title2.weight(.semibold))
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
        }
        
        .buttonStyle(.borderedProminent)
        
    }
    .padding()
}
