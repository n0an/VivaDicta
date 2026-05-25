// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Contract for filesystem and format operations on recorded audio files.
/// Pulled out of `RecordViewModel` so the view model never reaches into
/// `FileManager` or `AVAudioConverter` directly - both make tests painful
/// because they have real side effects and require disk/AV state.
///
/// Implementations are `Sendable` because the methods are pure functions
/// of their arguments (no shared mutable state).
public protocol AudioFileService: Sendable {
    func move(from source: URL, to destination: URL) throws
    func remove(at url: URL) throws
    func fileSize(at url: URL) throws -> Int64
    func duration(of url: URL) async throws -> TimeInterval

    /// Downsample the source audio to 16 kHz mono PCM Int16 at the
    /// destination URL. Used to shrink uploads to cloud transcription
    /// providers that don't need the original sample rate. The caller
    /// owns the destination URL (path, extension, cleanup).
    func downsampleTo16kHzMono(from source: URL, to destination: URL) async throws
}
