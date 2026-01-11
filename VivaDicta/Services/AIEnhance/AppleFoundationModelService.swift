//
//  AppleFoundationModelService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.11
//

import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Service for AI text enhancement using Apple's on-device Foundation Models
/// Available only on devices that support Apple Intelligence (iOS 18.4+)
@Observable
final class AppleFoundationModelService: Sendable {
    private let logger = Logger(category: .aiService)

    /// Check if Apple Foundation Models are available on this device
    @MainActor
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Detailed availability status for UI display
    @MainActor
    static var availabilityStatus: AppleFoundationModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            case .unavailable:
                return .unavailable
            @unknown default:
                return .unavailable
            }
        }
        #endif
        return .unavailable
    }

    /// Enhance text using Apple's on-device Foundation Model
    /// - Parameters:
    ///   - text: The transcription text to enhance
    ///   - systemPrompt: The system instructions for enhancement
    /// - Returns: The enhanced text
    func enhance(_ text: String, systemPrompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let isAvailable = await MainActor.run { Self.isAvailable }
            guard isAvailable else {
                throw AppleFoundationModelError.notAvailable
            }

            guard !text.isEmpty else {
                return ""
            }

            let formattedText = "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"

            logger.logNotice("Apple Foundation Model - Starting enhancement")

            let session = LanguageModelSession(instructions: systemPrompt)

            do {
                let response = try await session.respond(to: formattedText)
                let enhancedText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                let filteredText = AIEnhancementOutputFilter.filter(enhancedText)
                logger.logNotice("Apple Foundation Model - Enhancement completed")
                return filteredText
            } catch let error as LanguageModelSession.GenerationError {
                logger.logError("Apple Foundation Model generation error: \(error.localizedDescription)")
                throw AppleFoundationModelError.generationFailed(error.localizedDescription)
            }
        }
        #endif
        throw AppleFoundationModelError.notAvailable
    }

    /// Prewarm the model for faster first response
    @MainActor
    func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            guard Self.isAvailable else { return }
            let session = LanguageModelSession()
            session.prewarm()
            logger.logInfo("Apple Foundation Model - Prewarmed")
        }
        #endif
    }
}

// MARK: - Availability Status

enum AppleFoundationModelAvailability {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unavailable

    var description: String {
        switch self {
        case .available:
            return "Apple Intelligence is available"
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Enable it in Settings > Apple Intelligence & Siri"
        case .modelNotReady:
            return "Apple Intelligence is still setting up. Please try again later"
        case .unavailable:
            return "Apple Intelligence is unavailable"
        }
    }
}

// MARK: - Errors

enum AppleFoundationModelError: LocalizedError {
    case notAvailable
    case generationFailed(String)
    case guardrailViolation
    case refusal(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Foundation Model not available"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .guardrailViolation:
            return "Content blocked by safety guardrails"
        case .refusal(let reason):
            return "Request refused: \(reason)"
        }
    }

    var failureReason: String {
        switch self {
        case .notAvailable:
            return "Apple Intelligence is not available on this device. Please ensure you have a compatible device with Apple Intelligence enabled."
        case .generationFailed(let reason):
            return "The on-device AI model could not process the request: \(reason)"
        case .guardrailViolation:
            return "The content was blocked by Apple's safety guardrails. Please try with different content."
        case .refusal(let reason):
            return "The AI model refused to process this request: \(reason)"
        }
    }
}
