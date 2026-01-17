//
//  CustomTranscriptionModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.17
//

import Foundation

struct CustomTranscriptionModel: @MainActor TranscriptionModel, Codable {
    let id: UUID
    var name: String
    var displayName: String
    let description: String = "Custom transcription model"
    let provider: TranscriptionModelProvider = .customTranscription
    let recommended: Bool = false

    var apiEndpoint: String
    var modelName: String
    var isMultilingual: Bool

    var supportManyLanguages: Bool { isMultilingual }
    var supportedLanguages: [String: String] {
        isMultilingual ? TranscriptionModelProvider.allLanguages : ["en": "English"]
    }

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        apiEndpoint: String,
        modelName: String,
        isMultilingual: Bool = true
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.apiEndpoint = apiEndpoint
        self.modelName = modelName
        self.isMultilingual = isMultilingual
    }

    // Custom Codable to exclude computed properties
    enum CodingKeys: String, CodingKey {
        case id, name, displayName, apiEndpoint, modelName, isMultilingual
    }
}

extension CustomTranscriptionModel {
    var apiKey: String? {
        CustomTranscriptionModelManager.shared.getAPIKey(forModelId: id)
    }
}
