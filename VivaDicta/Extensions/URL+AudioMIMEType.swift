//
//  URL+AudioMIMEType.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.05
//

import Foundation

extension URL {
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
