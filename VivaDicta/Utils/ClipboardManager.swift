//
//  ClipboardManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.14
//

import UIKit

struct ClipboardManager {
    enum ClipboardError: Error {
        case copyFailed
        case accessDenied
    }
    
    static func copyToClipboard(_ text: String) -> Bool {
        UIPasteboard.general.string = text
        return true
    }
    
    static func getClipboardContent() -> String? {
        return UIPasteboard.general.string
    }
}
