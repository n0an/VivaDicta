// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import TranscriptionCore

/// A `TranscriptionService` wrapper that pre-binds a `WhisperKitTranscriptionService`
/// instance to a model name + options. Lets callers participate in the
/// unified `TranscriptionService` protocol while still benefiting from the
/// underlying service's model-caching behavior (the same service instance
/// can serve multiple operations with different models).
///
/// Build one with `WhisperKitTranscriptionService.operation(...)`.
public struct WhisperKitTranscribeOperation: TranscriptionService, @unchecked Sendable {
    public let service: WhisperKitTranscriptionService
    public let modelName: String
    public let displayName: String?
    public let options: WhisperKitTranscriptionService.Options

    public init(
        service: WhisperKitTranscriptionService,
        modelName: String,
        displayName: String? = nil,
        options: WhisperKitTranscriptionService.Options
    ) {
        self.service = service
        self.modelName = modelName
        self.displayName = displayName
        self.options = options
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        try await service.transcribe(
            audioURL: audioURL,
            modelName: modelName,
            displayName: displayName,
            options: options
        )
    }
}

public extension WhisperKitTranscriptionService {
    /// Returns a `TranscriptionService`-conforming wrapper pre-configured for
    /// this model + options. Multiple operations can share the same underlying
    /// service so model loads aren't repeated when the model name matches.
    func operation(
        modelName: String,
        displayName: String? = nil,
        options: Options
    ) -> WhisperKitTranscribeOperation {
        WhisperKitTranscribeOperation(
            service: self,
            modelName: modelName,
            displayName: displayName,
            options: options
        )
    }
}
