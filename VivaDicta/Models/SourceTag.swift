//
//  SourceTag.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.23
//

import SwiftUI

/// Constants and display helpers for transcription source tags.
///
/// Source tags identify where a transcription originated (in-app, keyboard extension, etc.)
/// and are automatically set at creation time.
enum SourceTag {
    static let app = "app"
    static let keyboard = "keyboard"
    static let shareExtension = "shareExtension"
    static let actionExtension = "actionExtension"
    static let macApp = "macApp"

    static func displayName(for tag: String?) -> String {
        switch tag {
        case app: "In-App"
        case keyboard: "Keyboard"
        case shareExtension: "Shared"
        case actionExtension: "Action"
        case macApp: "Mac"
        default: "Unknown"
        }
    }

    static func icon(for tag: String?) -> String {
        switch tag {
        case app: "mic.fill"
        case keyboard: "keyboard"
        case shareExtension: "square.and.arrow.down"
        case actionExtension: "bolt.fill"
        case macApp: "desktopcomputer"
        default: "questionmark.circle"
        }
    }

    static func color(for tag: String?) -> Color {
        switch tag {
        case app: .blue
        case keyboard: .purple
        case shareExtension: .orange
        case actionExtension: .green
        case macApp: .teal
        default: .secondary
        }
    }
}
