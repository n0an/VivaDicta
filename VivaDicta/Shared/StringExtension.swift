//
//  StringExtension.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.01.13
//

import Foundation

extension String {
    /// Truncates the string to the specified length, adding "..." if truncated
    func truncated(to maxLength: Int) -> String {
        if count <= maxLength {
            return self
        }
        return String(prefix(maxLength)) + "..."
    }
}
