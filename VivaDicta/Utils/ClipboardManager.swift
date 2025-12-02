//
//  ClipboardManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.14
//

import UIKit

struct ClipboardManager {
    static func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    static func getClipboardContent() -> String? {
        return UIPasteboard.general.string
    }
}
