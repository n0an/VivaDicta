//
//  AnalyticsService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.27
//

import Foundation
import FirebaseAnalytics
import os

/// Strongly-typed catalog of every analytics event the app reports.
///
/// Adding a new event:
/// 1. Add a case here with the parameters you want to attach.
/// 2. Map it in `name` and `parameters`.
/// 3. Call `AnalyticsService.track(.yourEvent(...))` from the relevant call site.
enum AnalyticsEvent {

    enum ChatType: String {
        case singleNote = "single_note"
        case multiNote = "multi_note"
        case allNotes = "all_notes"
        case smartSearch = "smart_search"
    }

    case onboardingCompleted
    case unrecognizedHostApp(bundleId: String)
    case keyboardSessionStarted(hostBundleId: String?)
    case modelDownloaded(name: String, type: String)

    case chatConversationStarted(
        chatType: ChatType,
        provider: String,
        model: String,
        noteCount: Int?
    )
    case chatMessageSent(
        chatType: ChatType,
        provider: String,
        model: String,
        turnCount: Int
    )

    case smartSearchQueryExecuted(queryLength: Int, topK: Int, resultCount: Int)
    case ragIndexingCompleted(
        indexedCount: Int,
        skippedCount: Int,
        totalChunks: Int,
        isFirstRun: Bool
    )

    case watchRecordingReceived(durationSeconds: Double?, hasModeId: Bool)

    case transcriptionCompleted(
        engine: String,
        isOnDevice: Bool,
        durationSeconds: Double,
        outputLength: Int
    )
    case variationGenerated(
        presetId: String,
        isBuiltInPreset: Bool,
        provider: String,
        model: String,
        durationSeconds: Double,
        outputLength: Int
    )
}

extension AnalyticsEvent {

    /// The Firebase event name. Keep names stable - changing one breaks
    /// historical reporting in the Firebase console.
    nonisolated var name: String {
        switch self {
        case .onboardingCompleted: "onboarding_completed"
        case .unrecognizedHostApp: "unrecognized_host_app"
        case .keyboardSessionStarted: "keyboard_session_started"
        case .modelDownloaded: "model_downloaded"
        case .chatConversationStarted: "chat_conversation_started"
        case .chatMessageSent: "chat_message_sent"
        case .smartSearchQueryExecuted: "smart_search_query_executed"
        case .ragIndexingCompleted: "rag_indexing_completed"
        case .watchRecordingReceived: "watch_recording_received"
        case .transcriptionCompleted: "transcription_completed"
        case .variationGenerated: "variation_generated"
        }
    }

    /// Parameters attached to the event. Keep keys snake_case and consistent
    /// across events (`provider`, `model`, `chat_type`, ...). Do not include
    /// raw user content - only counts, lengths, enum values, and IDs.
    nonisolated var parameters: [String: Any]? {
        switch self {
        case .onboardingCompleted:
            return nil

        case .unrecognizedHostApp(let bundleId):
            return ["bundle_id": bundleId]

        case .keyboardSessionStarted(let hostBundleId):
            return ["host_bundle_id": hostBundleId ?? "unknown"]

        case .modelDownloaded(let name, let type):
            return ["model_name": name, "model_type": type]

        case .chatConversationStarted(let chatType, let provider, let model, let noteCount):
            var params: [String: Any] = [
                "chat_type": chatType.rawValue,
                "provider": provider,
                "model": model
            ]
            if let noteCount { params["note_count"] = noteCount }
            return params

        case .chatMessageSent(let chatType, let provider, let model, let turnCount):
            return [
                "chat_type": chatType.rawValue,
                "provider": provider,
                "model": model,
                "turn_count": turnCount
            ]

        case .smartSearchQueryExecuted(let queryLength, let topK, let resultCount):
            return [
                "query_length": queryLength,
                "top_k": topK,
                "result_count": resultCount
            ]

        case .ragIndexingCompleted(let indexedCount, let skippedCount, let totalChunks, let isFirstRun):
            return [
                "indexed_count": indexedCount,
                "skipped_count": skippedCount,
                "total_chunks": totalChunks,
                "is_first_run": isFirstRun
            ]

        case .watchRecordingReceived(let durationSeconds, let hasModeId):
            var params: [String: Any] = ["has_mode_id": hasModeId]
            if let durationSeconds {
                params["duration_seconds"] = durationSeconds
            }
            return params

        case .transcriptionCompleted(let engine, let isOnDevice, let durationSeconds, let outputLength):
            return [
                "engine": engine,
                "is_on_device": isOnDevice,
                "duration_seconds": durationSeconds,
                "output_length": outputLength
            ]

        case .variationGenerated(let presetId, let isBuiltInPreset, let provider, let model, let durationSeconds, let outputLength):
            return [
                "preset_id": presetId,
                "is_built_in_preset": isBuiltInPreset,
                "provider": provider,
                "model": model,
                "duration_seconds": durationSeconds,
                "output_length": outputLength
            ]
        }
    }
}

/// Single chokepoint for reporting analytics events. Wraps Firebase Analytics
/// behind a typed API so call sites can't typo event names or drift in
/// parameter keys.
///
/// `Analytics.logEvent` is thread-safe; `track` can be called from any context.
enum AnalyticsService {
    nonisolated private static let logger = Logger(category: .analytics)

    nonisolated static func track(_ event: AnalyticsEvent) {
        let name = event.name
        let params = event.parameters
        Analytics.logEvent(name, parameters: params)

        if let params {
            logger.logDebug("📊 \(name) \(params)")
        } else {
            logger.logDebug("📊 \(name)")
        }
    }
}
