//
//  TranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import Foundation

protocol TranscriptionService {
    var selectedLanguage: Language { get set }
    func generateAudioTransciptions(fileURL: URL) async throws ->  String
}
