//
//  AppIntent.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 02.10.2025.
//

import WidgetKit
import SwiftUI
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configuration"
    static let description: IntentDescription = "Select color"

    // An example configurable parameter.
    @Parameter(title: "Color", default: "WidgetColorOrange")
    var widgetColorString: String
    
    var widgetColor: Color {
        return Color(widgetColorString)
    }
}

enum WidgetColor: String {
    case def = "WidgetColorOrange"
    case red = "WidgetColorRed"
    case blue = "WidgetColorBlue"
}
