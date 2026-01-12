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

/// Service for AI text enhancement using Apple's on-device Foundation Models
@available(iOS 26, *)
@MainActor
final class AppleFoundationModelService {
    private let logger = Logger(category: .aiService)

    /// The stored session - created during prewarm, used during enhance
    private var session: LanguageModelSession?

    /// The stored prompt prefix - saved during prewarm for use during enhance
    private var storedPromptPrefix: String?

    /// Prewarm the model for faster first response
    /// Creates a session with instructions and prewarms with the prompt prefix
    /// - Parameters:
    ///   - instructions: The base instructions for the session (role + rules + vocabulary)
    ///   - promptPrefix: The prompt prefix to prewarm with (user enhancement style)
    func prewarm(instructions: String, promptPrefix: String) {
        guard AppleFoundationModelAvailability.isAvailable else { return }

        // Create session with instructions and store it
        let newSession = LanguageModelSession(instructions: instructions)
        session = newSession
        storedPromptPrefix = promptPrefix

        // Prewarm with the prompt prefix
        let prefix = Prompt { promptPrefix }
        newSession.prewarm(promptPrefix: prefix)
        logger.logInfo("Apple Foundation Model - Session created and prewarmed with prompt prefix")
    }

    /// Clear the prewarmed session without using it
    /// Call this when recording is cancelled to avoid keeping unused session in memory
    func cancelPrewarm() {
        guard session != nil else { return }
        session = nil
        storedPromptPrefix = nil
        logger.logInfo("Apple Foundation Model - Prewarmed session cleared")
    }

    /// Enhance text using Apple's on-device Foundation Model
    /// Uses the prewarmed session if available, otherwise creates a new one
    /// - Parameters:
    ///   - text: The transcription text to enhance
    ///   - instructions: The base instructions (used if no prewarmed session exists)
    ///   - promptPrefix: The prompt prefix (user enhancement style)
    /// - Returns: The enhanced text
    func enhance(_ text: String, instructions: String, promptPrefix: String) async throws -> String {
        guard AppleFoundationModelAvailability.isAvailable else {
            throw AppleFoundationModelError.notAvailable
        }

        guard !text.isEmpty else {
            return ""
        }

        logger.logNotice("Apple Foundation Model - Starting enhancement")

        // Use prewarmed session if available, otherwise create new one
        let activeSession: LanguageModelSession
        if let existingSession = session {
            activeSession = existingSession
            logger.logInfo("Apple Foundation Model - Using prewarmed session")
        } else {
            activeSession = LanguageModelSession(instructions: instructions)
            logger.logInfo("Apple Foundation Model - Created new session (no prewarm)")
        }

        // Build full prompt: prefix + transcript
        let fullPrompt = Prompt {
            promptPrefix
            "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"
        }

        do {
            // Use greedy sampling for deterministic, consistent transcript cleaning
            let options = GenerationOptions(sampling: .greedy)
            let response = try await activeSession.respond(to: fullPrompt, options: options)
            let enhancedText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let filteredText = AIEnhancementOutputFilter.filter(enhancedText)
            logger.logNotice("Apple Foundation Model - Enhancement completed")

            // Debug: Print session transcript
            #if DEBUG
            logTranscript(activeSession)
            #endif

            // Clear session after use - next recording will prewarm fresh
            session = nil
            storedPromptPrefix = nil

            return filteredText
        } catch let error as LanguageModelSession.GenerationError {
            logger.logError("Apple Foundation Model generation error: \(error.localizedDescription)")

            // Debug: Print transcript even on error
            #if DEBUG
            logTranscript(activeSession)
            #endif

            session = nil
            storedPromptPrefix = nil
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
