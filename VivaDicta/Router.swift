//
//  Router.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.16
//

import SwiftUI

@Observable
@MainActor
class Router {
    var path = [Transcription]()

    func select(transcription: Transcription) {
        path = [transcription]
    }

    func popToRoot() {
        path = []
    }
}
