//
//  VivaDictaWidgetControl.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.10.02
//

import AppIntents
import SwiftUI
import WidgetKit

struct VivaDictaWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        
        StaticControlConfiguration(kind: "VivaDictaControlWidget") {
            ControlWidgetButton(action: ToggleRecordIntent()) {
                Image(systemName: "microphone.circle")
            }
        }
        
        .displayName("Start Recording")
        .description("Start Recording in VivaDicta")
    }
}
