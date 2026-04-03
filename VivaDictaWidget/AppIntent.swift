//
//  AppIntent.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 02.10.2025.
//

import WidgetKit
import SwiftUI
import AppIntents

// TODO: NOT USED AT THE MOMENT. CAN DELETE, OR USE - DECIDE LATER
// CURRENTLY USED ONLY VivaDictaIconWidget - IT DOESN'T USE ConfigurationAppIntent

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configuration"
    static let description: IntentDescription = "Select color"
    
    @Parameter(title: "Color", optionsProvider: ColorOptionsProvider())
    var widgetColorString: String?
    
    var widgetColor: WidgetColor {
        WidgetColor(rawValue: widgetColorString ?? WidgetColor.gradient1.rawValue) ?? .gradient1
    }
}

struct ColorOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        return WidgetColor.allCases.map { $0.rawValue }
    }

    func defaultResult() async -> String? { WidgetColor.gradient1.rawValue }
}

enum WidgetColor: String, CaseIterable {
    case gradient1
    case gradient2
    case orange
    case red
    case blue
    case green
    
    var meshGradientColors: [Color] {
        switch self {
        case .gradient1:
            return [
                .red, .purple, .indigo,
                .orange, .white, .blue,
                .yellow, .black, .mint
            ]
        case .gradient2:
            return [
                .blue, .red, .orange,
                .orange, .indigo, .red,
                .cyan, .purple, .mint
            ]
        case .orange:
            return [
                .orange, .yellow, .orange,
                .red.opacity(0.8), .orange, .yellow.opacity(0.8),
                .orange, .red.opacity(0.7), .orange
            ]
        case .red:
            return [
                .red, .pink, .red,
                .orange.opacity(0.8), .red, .pink.opacity(0.8),
                .red, .orange.opacity(0.7), .red
            ]
        case .blue:
            return [
                .blue, .cyan, .blue,
                .purple.opacity(0.8), .blue, .cyan.opacity(0.8),
                .blue, .indigo.opacity(0.7), .blue
            ]
        case .green:
            return [
                .green, .mint, .green,
                .teal.opacity(0.8), .green, .mint.opacity(0.8),
                .green, .cyan.opacity(0.7), .green
            ]
        }
    }
}
