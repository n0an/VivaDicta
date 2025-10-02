//
//  AppStateViewModel.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.02
//

import Foundation
import SwiftUI

/// View model for managing app state in the keyboard extension
@MainActor
@Observable
class AppStateViewModel {
    var isMainAppActive: Bool = false
}