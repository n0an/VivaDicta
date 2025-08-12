//
//  TranscribtionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import Foundation

protocol TranscribtionService {
    func generateAudioTransciptions(fileURL: URL) async throws ->  String
}
