// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Identifies which Parakeet model family to load. Mirrors FluidAudio's
/// `AsrModelVersion` but lives in TranscriptionCore so consumers (the
/// app's `ParakeetModel` catalog, extensions that share it via folder-sync,
/// and the `TranscriptionKit` engine) can name a version without pulling
/// in FluidAudio.
public enum ParakeetModelVersion: Sendable {
    case v2
    case v3
}
