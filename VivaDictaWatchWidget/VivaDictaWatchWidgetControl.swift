//
//  VivaDictaWatchWidgetControl.swift
//  VivaDictaWatchWidget
//
//  Created by Anton Novoselov on 2026.04.02
//

import AppIntents
import SwiftUI
import WidgetKit

struct VivaDictaWatchWidgetControl: ControlWidget {
    static let kind: String = "com.antonnovoselov.VivaDicta.watchkitapp.RecordControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenRecorderIntent()) {
                Label("Quick Record", systemImage: "mic.fill")
            }
        }
        .displayName("Quick Record")
        .description("Open VivaDicta and record a voice note.")
    }
}
