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
    
    @Parameter(title: "Color", optionsProvider: ColorOptionsProvider())
    var widgetColorString: String?
    
    var widgetColor: Color {
        let colorCase = WidgetColor(rawValue: widgetColorString ?? WidgetColor.def.rawValue) ?? .def
        return colorCase.color
    }
}

struct ColorOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        return WidgetColor.allCases.map { $0.rawValue }
    }

    func defaultResult() async -> String? { WidgetColor.def.rawValue }
}

enum WidgetColor: String, CaseIterable {
    case def = "Orange"
    case red = "Red"
    case blue = "Blue"
    case green = "Green"

    var color: Color {
        switch self {
        case .def: return .orange
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        }
    }
}
