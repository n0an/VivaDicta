//
//  Tip.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.16
//

import Foundation
import SwiftUI
import TipKit

struct SelectLanguageTip: Tip {
    var title: Text {
        Text("Select language")
            .foregroundStyle(
                MeshGradient(
                    width: 2,
                    height: 2,
                    points: [
                        [0, 0], [1, 0],
                        [0, 1], [1, 1]
                    ],
                    colors: [
                        .blue, .green,
                        .indigo, .teal
                    ]
                )
            )
    }
    
    var message: Text? {
        Text("Tap here to select language for better transcription")
    }

    var image: Image? {
        Image(systemName: "flag")
    }
    
}

struct SelectTranscriptionModelTipMainView: Tip {
    
    static let selectModelEvent = Event(id: "selectTranscriptionModel")
    
    @Parameter(.transient)
    static var isTranscriptionReady: Bool = false
    
    var title: Text {
        Text("Select Transcription model")
            .foregroundStyle(
                MeshGradient(
                    width: 2,
                    height: 2,
                    points: [
                        [0, 0], [1, 0],
                        [0, 1], [1, 1]
                    ],
                    colors: [
                        .blue, .green,
                        .indigo, .teal
                    ]
                )
            )
    }
    
    var message: Text? {
        Text("Tap here to set up a transcription model")
    }
    
    var image: Image? {
        Image(systemName: "waveform")
    }
    
    var actions: [Action] {
        [
            Tip.Action(id: "go-to-models", title: "Open Models")
        ]
    }
    
    var rules: [Rule] {
        #Rule(Self.selectModelEvent) { event in
            event.donations.count == 0
        }
    }
}

struct SelectTranscriptionModelTipSettingsView: Tip {
    
    static let selectModelEvent = Event(id: "selectTranscriptionModel")
    
    @Parameter(.transient)
    static var isTranscriptionReady: Bool = false
    
    
    var title: Text {
        Text("Select Transcription model")
            .foregroundStyle(
                MeshGradient(
                    width: 2,
                    height: 2,
                    points: [
                        [0, 0], [1, 0],
                        [0, 1], [1, 1]
                    ],
                    colors: [
                        .blue, .green,
                        .indigo, .teal
                    ]
                )
            )
    }
    
    var message: Text? {
        Text("Tap here to set up a transcription model")
    }

    var image: Image? {
        Image(systemName: "waveform")
    }
    
    var rules: [Rule] {
        #Rule(Self.selectModelEvent) { event in
            event.donations.count == 0
        }
    }

}

struct SelectAIEnhacementTip: Tip {
    var title: Text {
        Text("Add AI Processing")
    }

    var message: Text? {
        Text("Improve transcriptions with AI")
    }

    var image: Image? {
        Image(systemName: "wand.and.sparkles")
    }

}

struct TranscriptTagsTip: Tip {
    static let promptEditOpenedEvent = Event(id: "promptEditOpened")

    var title: Text {
        Text("Tip: Using <TRANSCRIPT> tag")
            .foregroundStyle(
                MeshGradient(
                    width: 2,
                    height: 2,
                    points: [
                        [0, 0], [1, 0],
                        [0, 1], [1, 1]
                    ],
                    colors: [
                        .purple, .red,
                        .blue, .pink
                    ]
                )
            )
    }

    var message: Text? {
        Text("Use <TRANSCRIPT> in your instructions to reference the transcribed text")
    }

    var image: Image? {
        Image(systemName: "chevron.left.forwardslash.chevron.right")
    }

    var rules: [Rule] {
        #Rule(Self.promptEditOpenedEvent) { event in
            event.donations.count >= 3
        }
    }
}

// MARK: - 3.0 Feature Discovery Tips

private nonisolated func discoveryMeshGradient() -> MeshGradient {
    MeshGradient(
        width: 2,
        height: 2,
        points: [
            [0, 0], [1, 0],
            [0, 1], [1, 1]
        ],
        colors: [
            .blue, .purple,
            .indigo, .pink
        ]
    )
}

struct ChatsDiscoveryTip: Tip {
    static let transcriptionCreatedEvent = Event(id: "transcriptionCreated")
    static let chatsOpenedEvent = Event(id: "chatsOpened")

    var title: Text {
        Text("Chat With Your Notes")
            .foregroundStyle(discoveryMeshGradient())
    }

    var message: Text? {
        Text("Ask questions about any note, or chat across many at once.")
    }

    var image: Image? {
        Image(systemName: "bubble.left.and.text.bubble.right.fill")
    }

    var rules: [Rule] {
        #Rule(Self.transcriptionCreatedEvent) { event in
            event.donations.count >= 3
        }
        #Rule(Self.chatsOpenedEvent) { event in
            event.donations.count == 0
        }
    }
}

struct SmartSearchDiscoveryTip: Tip {
    static let smartSearchPerformedEvent = Event(id: "smartSearchPerformed")

    var title: Text {
        Text("Search by Meaning")
            .foregroundStyle(discoveryMeshGradient())
    }

    var message: Text? {
        Text("Ask \"what did I say about pricing?\" and Smart AI Search finds it - even without exact words.")
    }

    var image: Image? {
        Image(systemName: "magnifyingglass.circle.fill")
    }

    var rules: [Rule] {
        #Rule(ChatsDiscoveryTip.transcriptionCreatedEvent) { event in
            event.donations.count >= 5
        }
        #Rule(Self.smartSearchPerformedEvent) { event in
            event.donations.count == 0
        }
    }
}

struct AIVariationsDiscoveryTip: Tip {
    static let variationGeneratedEvent = Event(id: "variationGenerated")

    @Parameter(.transient)
    static var isAIConfigured: Bool = false

    var title: Text {
        Text("Try Different AI Versions")
            .foregroundStyle(discoveryMeshGradient())
    }

    var message: Text? {
        Text("Generate summaries, rewrites, or translations. Each result is saved as a variation you can compare.")
    }

    var image: Image? {
        Image(systemName: "sparkles")
    }

    var rules: [Rule] {
        #Rule(Self.variationGeneratedEvent) { event in
            event.donations.count == 0
        }
        #Rule(Self.$isAIConfigured) { $0 == true }
    }
}

// MARK: - 3.2 Feature Discovery Tips

struct LiveTranslationDiscoveryTip: Tip {
    /// Reuses the existing transcription donation so the tip waits until the
    /// user has actually engaged with the app before nudging them toward a
    /// new feature.
    static let liveTranslationOpenedEvent = Event(id: "liveTranslationOpened")

    var title: Text {
        Text("Live Translation")
            .foregroundStyle(discoveryMeshGradient())
    }

    var message: Text? {
        Text("Speak in one language, hear it back in another in near real time. 60+ languages, plug in headphones.")
    }

    var image: Image? {
        Image(systemName: "globe.americas.fill")
    }

    var rules: [Rule] {
        // Only after the user has done a few transcriptions - so we don't
        // bombard fresh installs with a tip about a side feature.
        #Rule(ChatsDiscoveryTip.transcriptionCreatedEvent) { event in
            event.donations.count >= 3
        }
        // Don't keep nagging once the user has actually opened Live Translation.
        #Rule(Self.liveTranslationOpenedEvent) { event in
            event.donations.count == 0
        }
    }
}

struct NativeTranslationTip: Tip {
    var title: Text {
        Text("One-step translation")
            .foregroundStyle(discoveryMeshGradient())
    }

    var message: Text? {
        Text("This provider translates while it transcribes. Pick a target and your transcription comes back already translated - no extra AI processing step.")
    }

    var image: Image? {
        Image(systemName: "text.bubble.fill")
    }
}

struct SingleNoteChatDiscoveryTip: Tip {
    static let singleNoteChatOpenedEvent = Event(id: "singleNoteChatOpened")

    @Parameter(.transient)
    static var isAIConfigured: Bool = false

    var title: Text {
        Text("Ask This Note Questions")
            .foregroundStyle(discoveryMeshGradient())
    }

    var message: Text? {
        Text("Dig into what you recorded - get summaries, clarifications, or action items.")
    }

    var image: Image? {
        Image(systemName: "bubble.left.and.text.bubble.right")
    }

    var rules: [Rule] {
        #Rule(Self.singleNoteChatOpenedEvent) { event in
            event.donations.count == 0
        }
        #Rule(Self.$isAIConfigured) { $0 == true }
    }
}

