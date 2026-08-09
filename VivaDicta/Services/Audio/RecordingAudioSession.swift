//
//  RecordingAudioSession.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.09
//

import AVFoundation
import AppGroup
import Foundation
import os

/// Which microphone recording asks iOS for.
enum PreferredMicrophone: String, CaseIterable, Sendable {
    /// Pin the built-in mic. Keeps AirPods in A2DP - they are never pulled
    /// into the low-quality HFP profile - and generally transcribes better.
    case builtIn

    /// Let iOS choose, which means the connected headset when there is one.
    case automatic

    static let `default`: PreferredMicrophone = .builtIn
}

/// One place to configure the shared `AVAudioSession` for recording.
///
/// Three call sites used to configure it independently and had already drifted
/// apart - the prewarm engine, Live Translation, and the streaming capture.
/// Anything that touches the mic route (input preference, Bluetooth options)
/// has to be applied consistently or fixing one path silently leaves the
/// others behaving differently, so it lives here.
enum RecordingAudioSession {
    private static let logger = Logger(category: .recordingAudioSession)

    static var preferredMicrophone: PreferredMicrophone {
        get {
            let raw = UserDefaultsStorage.shared.string(forKey: UserDefaultsStorage.Keys.preferredMicrophone)
            return raw.flatMap(PreferredMicrophone.init(rawValue:)) ?? .default
        }
        set {
            UserDefaultsStorage.shared.set(newValue.rawValue, forKey: UserDefaultsStorage.Keys.preferredMicrophone)
        }
    }

    /// Adds the Bluetooth options appropriate for the current preference.
    ///
    /// `.allowBluetoothHFP` is what lets a headset mic be used at all, at the
    /// cost of dragging playback down to headset quality. iOS 26's
    /// `.bluetoothHighQualityRecording` asks the system for the better route
    /// when the device supports it, falling back to HFP when it doesn't - so
    /// it is added alongside rather than instead of HFP.
    ///
    /// When the built-in mic is preferred there is no reason to request the
    /// Bluetooth mic route at all, and not requesting it is what keeps AirPods
    /// in A2DP.
    static func categoryOptions(
        base: AVAudioSession.CategoryOptions
    ) -> AVAudioSession.CategoryOptions {
        var options = base

        guard preferredMicrophone == .automatic else {
            options.remove(.allowBluetoothHFP)
            return options
        }

        options.insert(.allowBluetoothHFP)
        if #available(iOS 26.0, *) {
            options.insert(.bluetoothHighQualityRecording)
        }
        return options
    }

    /// Pins the input device. Call after `setActive(true)` and before building
    /// the engine and its tap - a preferred input set before activation does
    /// not stick.
    static func applyPreferredInput(to session: AVAudioSession) {
        guard preferredMicrophone == .builtIn else {
            // Automatic: clear any pin so iOS is free to pick the connected device.
            try? session.setPreferredInput(nil)
            return
        }

        guard let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
            logger.logWarning("Built-in mic preferred but not among available inputs")
            return
        }

        do {
            try session.setPreferredInput(builtIn)
        } catch {
            logger.logWarning("Failed to pin built-in mic: \(error.localizedDescription)")
        }
    }
}
