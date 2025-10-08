//
//  AppStateViewModel.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.02
//

import Foundation
import SwiftUI

/// View model for managing app state in the keyboard extension
@Observable
class AppStateViewModel {
    public var isMainAppActive: Bool = false
    public var isRecording: Bool = false
}
