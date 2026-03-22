//
//  AppleFoundationModelService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.11
//

import Foundation
import FoundationModels
import os

// MARK: - Service

/// Service for AI text enhancement using Apple's on-device Foundation Models.
///
/// Uses the same system message + user message pattern as cloud providers.
/// The system message becomes session instructions, the user message becomes the prompt.
@available(iOS 26, *)
@MainActor
final class AppleFoundationModelService {
    private let logger = Logger(category: .aiService)

    /// Enhance text using Apple's on-device Foundation Model.
    /// - Parameters:
    ///   - systemMessage: The system message (same as cloud providers)
    ///   - userMessage: The formatted user message (transcript, optionally wrapped in tags)
    /// - Returns: The enhanced text
    func enhance(systemMessage: String, userMessage: String) async throws -> String {
        guard AppleFoundationModelAvailability.isAvailable else {
            throw AppleFoundationModelError.notAvailable
        }

        guard !userMessage.isEmpty else {
            return ""
        }

        logger.logNotice("Apple Foundation Model - Starting enhancement")
        
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        
        let session = LanguageModelSession(model: model, instructions: systemMessage)
        let prompt = Prompt { userMessage }

        do {
            // Use greedy sampling for deterministic, consistent transcript cleaning
            let options = GenerationOptions(sampling: .greedy)
            let response = try await session.respond(to: prompt, options: options)
            let enhancedText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let filteredText = AIEnhancementOutputFilter.filter(enhancedText)
            logger.logNotice("Apple Foundation Model - Enhancement completed")

            #if DEBUG
            logTranscript(session)
            #endif

            return filteredText
        } catch is CancellationError {
            logger.logInfo("Apple Foundation Model - Enhancement cancelled")
            throw CancellationError()
        } catch let error as LanguageModelSession.GenerationError {
            logger.logError("Apple Foundation Model generation error: \(error.localizedDescription)")

            #if DEBUG
            logTranscript(session)
            #endif

            switch error {
            case .guardrailViolation(let context):
                logger.logWarning("Safety guardrail triggered: \(context.debugDescription)")
                throw AppleFoundationModelError.guardrailViolation
            case .exceededContextWindowSize:
                logger.logWarning("Context window size exceeded")
                throw AppleFoundationModelError.generationFailed("Context window size exceeded")
            default:
                throw AppleFoundationModelError.generationFailed(error.localizedDescription)
            }
        } catch {
            logger.logError("Apple Foundation Model unexpected error: \(error.localizedDescription)")
            throw AppleFoundationModelError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Debug

    #if DEBUG
    private func logTranscript(_ session: LanguageModelSession) {
        logger.logDebug("=== FOUNDATION MODEL SESSION TRANSCRIPT ===")

        for entry in session.transcript {
            switch entry {
            case .instructions(let instructions):
                logger.logDebug("INSTRUCTIONS: \(instructions.segments.map { "\($0)" }.joined(separator: " "))")
            case .prompt(let prompt):
                logger.logDebug("PROMPT: \(prompt.segments.map { "\($0)" }.joined(separator: " "))")
            case .response(let response):
                logger.logDebug("RESPONSE: \(response.segments.map { "\($0)" }.joined(separator: " "))")
            case .toolCalls(let toolCalls):
                logger.logDebug("TOOL CALLS: \(toolCalls)")
            case .toolOutput(let toolOutput):
                logger.logDebug("TOOL OUTPUT: \(toolOutput)")
            @unknown default:
                logger.logDebug("UNKNOWN ENTRY: \(entry)")
            }
        }

        logger.logDebug("=== END TRANSCRIPT ===")
    }
    #endif
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

    /// Check if Apple Foundation Models are available on this device
    @MainActor
    static var isAvailable: Bool {
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
    }

    /// Detailed availability status for UI display
    @MainActor
    static var currentStatus: AppleFoundationModelAvailability {
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
        return .unavailable
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
