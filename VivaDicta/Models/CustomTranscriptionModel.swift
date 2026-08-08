//
//  CustomTranscriptionModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.17
//

import CloudTranscription
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
    var requestFormat: CustomTranscriptionRequestFormat

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
        isMultilingual: Bool = true,
        requestFormat: CustomTranscriptionRequestFormat = .multipartFormData
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.apiEndpoint = apiEndpoint
        self.modelName = modelName
        self.isMultilingual = isMultilingual
        self.requestFormat = requestFormat
    }

    // Custom Codable to exclude computed properties
    enum CodingKeys: String, CodingKey {
        case id, name, displayName, apiEndpoint, modelName, isMultilingual, requestFormat
    }

    // Hand-written so configurations saved before `requestFormat` existed keep
    // decoding, falling back to the multipart body they were set up against.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decode(String.self, forKey: .displayName)
        apiEndpoint = try container.decode(String.self, forKey: .apiEndpoint)
        modelName = try container.decode(String.self, forKey: .modelName)
        isMultilingual = try container.decode(Bool.self, forKey: .isMultilingual)
        requestFormat = try container.decodeIfPresent(
            CustomTranscriptionRequestFormat.self,
            forKey: .requestFormat
        ) ?? .multipartFormData
    }
}

extension CustomTranscriptionModel {
    var apiKey: String? {
        CustomTranscriptionModelManager.shared.getAPIKey(forModelId: id)
    }
}
