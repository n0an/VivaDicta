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
//        #Rule(Self.$isTranscriptionReady) { $0 == false }
        
        #Rule(Self.selectModelEvent) { event in
            event.donations.count == 0
        }
    }
    
//    var options: [Option] {
//        MaxDisplayCount(20)
//    }
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
//        #Rule(Self.$isTranscriptionReady) { $0 == false }
        
        #Rule(Self.selectModelEvent) { event in
            event.donations.count == 0
        }
    }
    
}

struct SelectAIEnhacementTip: Tip {
    var title: Text {
        Text("Add AI Processing")
//            .foregroundStyle(MeshGradient(
//                width: 2,
//                height: 2,
//                points: [
//                    [0, 0], [1, 0],
//                    [0, 1], [1, 1]
//                ],
//                colors: [
//                    .purple, .red,
//                    .blue, .pink
//                ]
//            ))
        
    }

    var message: Text? {
        Text("Improve transcriptions with AI")
//            .foregroundStyle(MeshGradient(
//                width: 2,
//                height: 2,
//                points: [
//                    [0, 0], [1, 0],
//                    [0, 1], [1, 1]
//                ],
//                colors: [
//                    .purple, .red,
//                    .blue, .pink
//                ]
//            ))
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
