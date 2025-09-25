//
//  VivaDictaTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2025.08.30
//

import Testing
@testable import VivaDicta

struct VivaDictaTests {

    @Test func testCoreMLRestrictedToMediumAndSmaller() async throws {
        // Get all local models from TranscriptionModelProvider
        let allLocalModels = TranscriptionModelProvider.allLocalModels

        for model in allLocalModels {
            if model.name.contains("large") {
                // Large models should not have CoreML URL
                #expect(model.coreMLDownloadURL == nil, "Large model '\(model.name)' should not have CoreML URL")
            } else if model.name.contains("q5") || model.name.contains("q8") {
                // Quantized models should not have CoreML URL
                #expect(model.coreMLDownloadURL == nil, "Quantized model '\(model.name)' should not have CoreML URL")
            } else if model.name.contains("tiny") || model.name.contains("base") ||
                      model.name.contains("small") || model.name.contains("medium") {
                // Small/Medium models should have CoreML URL
                #expect(model.coreMLDownloadURL != nil, "Model '\(model.name)' should have CoreML URL")
            }
        }
    }

    @Test func testIsLargeModelProperty() async throws {
        // Test the isLargeModel property directly
        let largeModel = WhisperLocalModel(
            name: "large-v3",
            displayName: "Large v3",
            description: "Test",
            size: "3GB",
            speed: 1.0,
            accuracy: 1.0,
            ramUsage: 3.0,
            supportedLanguages: [:]
        )

        let largeTurboModel = WhisperLocalModel(
            name: "large-v3-turbo",
            displayName: "Large v3 Turbo",
            description: "Test",
            size: "1.5GB",
            speed: 2.0,
            accuracy: 0.95,
            ramUsage: 1.5,
            supportedLanguages: [:]
        )

        let mediumModel = WhisperLocalModel(
            name: "medium",
            displayName: "Medium",
            description: "Test",
            size: "1.5GB",
            speed: 2.0,
            accuracy: 0.9,
            ramUsage: 1.5,
            supportedLanguages: [:]
        )

        let tinyModel = WhisperLocalModel(
            name: "tiny",
            displayName: "Tiny",
            description: "Test",
            size: "39MB",
            speed: 10.0,
            accuracy: 0.7,
            ramUsage: 0.1,
            supportedLanguages: [:]
        )

        #expect(largeModel.isLargeModel == true, "large-v3 should be identified as large model")
        #expect(largeTurboModel.isLargeModel == true, "large-v3-turbo should be identified as large model")
        #expect(mediumModel.isLargeModel == false, "medium should not be identified as large model")
        #expect(tinyModel.isLargeModel == false, "tiny should not be identified as large model")
    }

}
