//
//  RecordingOrbStyle.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.30
//

import Foundation

/// Visualization shown on the recording screen. `particles` is the default and
/// lightest option; `ascii` is the audio-reactive ASCII orb (heavier per frame);
/// `hidden` shows no visualization at all.
enum RecordingOrbStyle: String, CaseIterable, Identifiable, Sendable {
    case particles
    case ascii
    case hidden

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .particles: return "Particles"
        case .ascii: return "ASCII"
        case .hidden: return "None"
        }
    }
}
