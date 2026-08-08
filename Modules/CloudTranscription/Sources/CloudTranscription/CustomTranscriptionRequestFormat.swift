// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// How `CustomTranscriptionService` puts the audio on the wire.
///
/// OpenAI's own `/audio/transcriptions` takes a binary `multipart/form-data`
/// upload and most self-hosted Whisper servers copy that, so it stays the
/// default. Some gateways instead expect a JSON body whose `file` field is a
/// base64 data URI and answer multipart with HTTP 400, which is why the
/// format is user-selectable per custom endpoint.
public enum CustomTranscriptionRequestFormat: String, Codable, Sendable, CaseIterable {
    /// `multipart/form-data` with the raw audio bytes as the `file` part.
    case multipartFormData

    /// `application/json` with the audio inlined into `file` as
    /// `data:<mime-type>;base64,<payload>`.
    case jsonBase64
}
