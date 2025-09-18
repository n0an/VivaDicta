//
//  TranscriptionServiceProtocol.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import Foundation

protocol TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String
}
