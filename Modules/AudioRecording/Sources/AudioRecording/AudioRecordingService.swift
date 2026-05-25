// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Contract for capturing microphone audio to a file. Wraps the platform
/// recorder (AVAudioRecorder on iOS, equivalent on macOS) so consumers can
/// be tested without touching real hardware or audio session state.
///
/// The protocol is `@MainActor` because every concrete iOS implementation
/// ends up touching `AVAudioSession` and `AVAudioRecorder`, both of which
/// are safest to drive from the main actor. Consumers (`RecordViewModel`)
/// are already main-actor isolated, so this costs nothing at the call site.
///
/// ## Lifecycle
///
/// ```
/// startRecording(to:settings:) → (recording) → stopRecording() → URL?
/// ```
///
/// `currentAudioPower` is the latest average power in dB (negative scale,
/// `-160` = silence, `0` = full scale). Consumers are responsible for any
/// normalization they want to show in the UI.
@MainActor
public protocol AudioRecordingService: AnyObject {
    var isRecording: Bool { get }
    var currentTime: TimeInterval { get }
    var currentAudioPower: Float { get }

    /// Configure the audio session and start recording to the given URL.
    /// Throws if the session fails to activate or the recorder cannot be
    /// constructed with the provided settings.
    func startRecording(to url: URL, settings: [String: Any]) throws

    /// Stop the active recording. Returns the URL of the finished file, or
    /// `nil` if no recording was in progress.
    func stopRecording() -> URL?
}
