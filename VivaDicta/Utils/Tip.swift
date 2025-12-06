//
//  Tip.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.16
//

import Foundation
import TipKit

struct SelectLanguageTip: Tip {
    var title: Text {
        Text("Select language")
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
            .foregroundStyle(.teal)
    }
    
    var message: Text? {
        Text("Tap here to download local or select cloud transcription model")
    }
    
    var image: Image? {
        Image(systemName: "cpu.fill")
    }
    
    var actions: [Action] {
        [
            Tip.Action(id: "go-to-models", title: "Open Models")
        ]
    }
    
    var rules: [Rule] {
        #Rule(Self.$isTranscriptionReady) { $0 == false }
        
        #Rule(Self.selectModelEvent) { event in
            event.donations.count < 10
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
            .foregroundStyle(.teal)
    }
    
    var message: Text? {
        Text("Tap here to download local or select cloud transcription model")
            .foregroundStyle(.orange)
    }

    var image: Image? {
        Image(systemName: "cpu.fill")
    }
    
    var rules: [Rule] {
        #Rule(Self.$isTranscriptionReady) { $0 == false }
        
        #Rule(Self.selectModelEvent) { event in
            event.donations.count < 10
        }
    }
    
}

struct SelectAIEnhacementTip: Tip {
    var title: Text {
        Text("Add AI Enhancement")
    }
    
    var message: Text? {
        Text("Improve transcriptions with AI")
    }

    var image: Image? {
        Image(systemName: "wand.and.sparkles")
    }
    
}
