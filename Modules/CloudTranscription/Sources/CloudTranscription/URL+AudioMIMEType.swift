// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

public extension URL {
    var audioMIMEType: String {
        switch pathExtension.lowercased() {
        case "m4a": "audio/mp4"
        case "mp3": "audio/mpeg"
        case "flac": "audio/flac"
        case "ogg": "audio/ogg"
        case "webm": "audio/webm"
        default: "audio/wav"
        }
    }
}
