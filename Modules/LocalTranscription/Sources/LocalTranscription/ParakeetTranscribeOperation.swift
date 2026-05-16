// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
@preconcurrency import FluidAudio
import TranscriptionCore

/// A `TranscriptionService` wrapper that pre-binds a `ParakeetTranscriptionService`
/// instance to a model + options. Lets callers participate in the unified
/// `TranscriptionService` protocol while keeping the underlying service's
/// model caching and progress-handler support.
///
/// Build one with `ParakeetTranscriptionService.operation(...)`.
public struct ParakeetTranscribeOperation: TranscriptionService, @unchecked Sendable {
    public let service: ParakeetTranscriptionService
    public let modelName: String
    public let displayName: String?
    public let version: AsrModelVersion
    public let options: ParakeetTranscriptionService.Options
    public let progressHandler: TranscriptionProgressHandler?

    public init(
        service: ParakeetTranscriptionService,
        modelName: String,
        displayName: String? = nil,
        version: AsrModelVersion,
        options: ParakeetTranscriptionService.Options,
        progressHandler: TranscriptionProgressHandler? = nil
    ) {
        self.service = service
        self.modelName = modelName
        self.displayName = displayName
        self.version = version
        self.options = options
        self.progressHandler = progressHandler
    }

    public func transcribe(audioURL: URL) async throws -> TranscriptionServiceResult {
        try await service.transcribe(
            audioURL: audioURL,
            modelName: modelName,
            displayName: displayName,
            version: version,
            options: options,
            progressHandler: progressHandler
        )
    }
}

public extension ParakeetTranscriptionService {
    /// Returns a `TranscriptionService`-conforming wrapper pre-configured for
    /// this model version + options + optional progress handler.
    func operation(
        modelName: String,
        displayName: String? = nil,
        version: AsrModelVersion,
        options: Options,
        progressHandler: TranscriptionProgressHandler? = nil
    ) -> ParakeetTranscribeOperation {
        ParakeetTranscribeOperation(
            service: self,
            modelName: modelName,
            displayName: displayName,
            version: version,
            options: options,
            progressHandler: progressHandler
        )
    }
}
