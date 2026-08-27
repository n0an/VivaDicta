//
//  TranscriptionModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import Foundation

protocol TranscriptionModel: Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
    var displayName: String { get }
    var description: String { get }
    var provider: TranscriptionModelProvider { get }
    var recommended: Bool { get }
    
    // Language capabilities
    var supportManyLanguages: Bool { get }
    var supportedLanguages: [String: String] { get }
}

extension TranscriptionModel {
    var language: String {
        supportManyLanguages ? "All Languages" : "English-only"
    }

    /// Whether this specific model can return speaker-labeled output.
    ///
    /// A provider-level capability everywhere except OpenAI, where only the
    /// dedicated `gpt-4o-transcribe-diarize` model diarizes.
    var supportsSpeakerDiarization: Bool {
        if provider == .openAI { return name == "gpt-4o-transcribe-diarize" }
        return provider.supportsSpeakerDiarization
    }

    /// Whether this specific model can translate inline.
    ///
    /// Speechmatics' Melia-1 is the exception: translation is Enhanced/Standard
    /// only, and Speechmatics rejects a Melia-1 job carrying a
    /// `translation_config`.
    var supportsNativeTranslation: Bool {
        if name == "melia-1" { return false }
        return provider.supportsNativeTranslation
    }
}
