//
//  PreviewContainer.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import SwiftUI
import SwiftData

struct TranscriptionsMockData: PreviewModifier {

    static func makeSharedContext() async throws -> ModelContainer {
        let container = try ModelContainer(for: Transcription.self, configurations: .init(isStoredInMemoryOnly: true))
        Transcription.mockData.forEach { container.mainContext.insert($0) }
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var transcriptionsMockData: Self = .modifier(TranscriptionsMockData())
}
