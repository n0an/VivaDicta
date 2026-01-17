//
//  CustomTranscriptionModelManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.17
//

import Foundation
import os

@Observable
@MainActor
final class CustomTranscriptionModelManager {
    static let shared = CustomTranscriptionModelManager()

    private let logger = Logger(category: .customTranscriptionService)

    /// The single custom transcription model configuration
    private(set) var customModel: CustomTranscriptionModel

    private let userDefaultsKey = "customTranscriptionModel"
    private let apiKeyKey = "apiKey.customTranscription"

    /// Fixed model ID for the singleton custom model
    private static let fixedModelId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private init() {
        // Initialize with empty model first
        customModel = CustomTranscriptionModel(
            id: Self.fixedModelId,
            name: "custom",
            displayName: "Custom",
            apiEndpoint: "",
            modelName: "",
            isMultilingual: true
        )
        loadModel()
    }

    /// Whether the custom model is configured (has endpoint and model name)
    var isConfigured: Bool {
        !customModel.apiEndpoint.isEmpty && !customModel.modelName.isEmpty
    }

    /// Returns the custom model only if it's configured, otherwise nil
    var configuredModel: CustomTranscriptionModel? {
        isConfigured ? customModel : nil
    }

    // MARK: - Save/Update

    func saveConfiguration(apiEndpoint: String, apiKey: String, modelName: String, isMultilingual: Bool) -> Bool {
        let errors = validateConfiguration(apiEndpoint: apiEndpoint, modelName: modelName)
        guard errors.isEmpty else {
            return false
        }

        // Save API key
        if !apiKey.isEmpty {
            UserDefaultsStorage.shared.set(apiKey, forKey: apiKeyKey)
        } else {
            UserDefaultsStorage.shared.removeObject(forKey: apiKeyKey)
        }

        // Update model
        customModel = CustomTranscriptionModel(
            id: Self.fixedModelId,
            name: "custom",
            displayName: "Custom",
            apiEndpoint: apiEndpoint.trimmingCharacters(in: .whitespaces),
            modelName: modelName.trimmingCharacters(in: .whitespaces),
            isMultilingual: isMultilingual
        )

        saveModel()
        logger.logInfo("Custom transcription model configuration saved")
        return true
    }

    func clearConfiguration() {
        UserDefaultsStorage.shared.removeObject(forKey: apiKeyKey)
        customModel = CustomTranscriptionModel(
            id: Self.fixedModelId,
            name: "custom",
            displayName: "Custom",
            apiEndpoint: "",
            modelName: "",
            isMultilingual: true
        )
        saveModel()
        logger.logInfo("Custom transcription model configuration cleared")
    }

    // MARK: - API Key Management

    func getAPIKey(forModelId id: UUID) -> String? {
        guard id == Self.fixedModelId else { return nil }
        return UserDefaultsStorage.shared.string(forKey: apiKeyKey)
    }

    var apiKey: String? {
        UserDefaultsStorage.shared.string(forKey: apiKeyKey)
    }

    // MARK: - Persistence

    private func loadModel() {
        guard let data = UserDefaultsStorage.shared.data(forKey: userDefaultsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            customModel = try decoder.decode(CustomTranscriptionModel.self, from: data)
            logger.logInfo("Loaded custom transcription model configuration")
        } catch {
            logger.logError("Failed to load custom transcription model: \(error.localizedDescription)")
        }
    }

    private func saveModel() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(customModel)
            UserDefaultsStorage.shared.set(data, forKey: userDefaultsKey)
        } catch {
            logger.logError("Failed to save custom transcription model: \(error.localizedDescription)")
        }
    }

    // MARK: - Validation

    func validateConfiguration(apiEndpoint: String, modelName: String) -> [String] {
        var errors: [String] = []

        if apiEndpoint.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("API endpoint is required")
        } else if !isValidURL(apiEndpoint) {
            errors.append("Invalid API endpoint URL")
        }

        if modelName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Model name is required")
        }

        return errors
    }

    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return false
        }
        return true
    }
}
