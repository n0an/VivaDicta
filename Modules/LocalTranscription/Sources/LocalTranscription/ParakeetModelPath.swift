// Copyright © 2026 Anton Novoselov. All rights reserved.

@preconcurrency import FluidAudio
import Foundation
import TranscriptionCore

/// Filesystem layout helper for Parakeet (FluidAudio) model packages.
/// Centralized in `LocalTranscription` so the app's model catalog can ask
/// "is this model downloaded?" without importing `FluidAudio` directly.
public enum ParakeetModelPath {
    /// Default cache directory FluidAudio uses for the given Parakeet model
    /// version. Mirrors what `AsrModels.downloadAndLoad(version:)` writes to.
    public static func directory(for version: ParakeetModelVersion) -> URL {
        AsrModels.defaultCacheDirectory(for: asrModelVersion(for: version))
    }

    /// Whether all required model files for the given version are present in
    /// FluidAudio's default cache directory.
    public static func isDownloaded(version: ParakeetModelVersion) -> Bool {
        let asrVersion = asrModelVersion(for: version)
        return AsrModels.modelsExist(at: directory(for: version), version: asrVersion)
    }
}

@inline(__always)
internal func asrModelVersion(for version: ParakeetModelVersion) -> AsrModelVersion {
    switch version {
    case .v2: return .v2
    case .v3: return .v3
    }
}
