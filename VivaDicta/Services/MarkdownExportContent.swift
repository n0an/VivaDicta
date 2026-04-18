//
//  MarkdownExportContent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import Foundation

enum MarkdownExportContent: String, CaseIterable, Identifiable, Sendable {
    case allVariations
    case originalOnly
    case originalAndLastVariation
    case lastVariationOnly

    nonisolated static let `default`: MarkdownExportContent = .allVariations
    nonisolated static let userDefaultsKey = "markdownExportContent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allVariations: "Original + All Variations"
        case .originalOnly: "Original Only"
        case .originalAndLastVariation: "Original + Last Variation"
        case .lastVariationOnly: "Last Variation Only"
        }
    }

    nonisolated static var current: MarkdownExportContent {
        guard
            let raw = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
            let value = MarkdownExportContent(rawValue: raw)
        else {
            return .default
        }
        return value
    }
}
