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
