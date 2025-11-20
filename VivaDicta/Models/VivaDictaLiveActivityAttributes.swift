//
//  VivaDictaLiveActivityAttributes.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.02
//

import Foundation
import ActivityKit

// Processing state for Live Activity
public enum LiveActivityState: String, Codable, Hashable {
    case idle
    case recording
    case transcribing
    case enhancing

    var iconName: String {
        switch self {
        case .idle, .recording:
            return "microphone.circle.fill"
        case .transcribing:
            return "pencil.and.scribble"
        case .enhancing:
            return "sparkles"
        }
    }

    var iconColor: String {
        switch self {
        case .idle, .recording:
            return "orange"
        case .transcribing, .enhancing:
            return "blue"
        }
    }

    var statusText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .enhancing:
            return "Enhancing"
        }
    }
}

struct VivaDictaLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var state: LiveActivityState
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}



extension VivaDictaLiveActivityAttributes {
    static var preview: VivaDictaLiveActivityAttributes {
        VivaDictaLiveActivityAttributes(name: "VivaDicta")
    }
}

extension VivaDictaLiveActivityAttributes.ContentState {
    static var idle: VivaDictaLiveActivityAttributes.ContentState {
        VivaDictaLiveActivityAttributes.ContentState(state: .idle)
    }

    static var recording: VivaDictaLiveActivityAttributes.ContentState {
        VivaDictaLiveActivityAttributes.ContentState(state: .recording)
    }

    static var transcribing: VivaDictaLiveActivityAttributes.ContentState {
        VivaDictaLiveActivityAttributes.ContentState(state: .transcribing)
    }

    static var enhancing: VivaDictaLiveActivityAttributes.ContentState {
        VivaDictaLiveActivityAttributes.ContentState(state: .enhancing)
    }
}
