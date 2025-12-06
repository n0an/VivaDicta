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
    
}

struct SelectTranscriptionModelTipSettingsView: Tip {
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
