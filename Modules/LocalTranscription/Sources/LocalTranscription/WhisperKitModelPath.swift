// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Filesystem layout helper for WhisperKit Core ML model packages. Centralized
/// so the service and the app's model-download manager agree on the path.
public enum WhisperKitModelPath {
    /// Root directory under Documents where WhisperKit models are downloaded.
    /// Matches HuggingFace's `argmaxinc/whisperkit-coreml` namespace layout.
    public static var root: URL {
        URL.documentsDirectory
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
    }

    /// Returns the directory URL for a given WhisperKit model name (e.g.
    /// `"openai_whisper-large-v3-turbo_632MB"`).
    public static func directory(forModelName modelName: String) -> URL {
        root.appendingPathComponent(modelName)
    }

    /// Whether the model has been downloaded to disk.
    public static func isDownloaded(modelName: String) -> Bool {
        FileManager.default.fileExists(atPath: directory(forModelName: modelName).path)
    }
}
