//
//  AIProvider.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import Foundation

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    var id: Self { self }
    
    case groq
    case gemini
    case anthropic
    case openAI
    case openRouter
    case grok
    case elevenLabs
    case deepgram
    
    var baseURL: String {
        switch self {
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .openRouter:
            return "https://openrouter.ai/api/v1/chat/completions"
        case .grok:
            return "https://api.x.ai/v1/chat/completions"
        case .elevenLabs:
            return "https://api.elevenlabs.io/v1/speech-to-text"
        case .deepgram:
            return "https://api.deepgram.com/v1/listen"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .groq:
            return "qwen/qwen3-32b"
        case .gemini:
            return "gemini-2.0-flash-lite"
        case .anthropic:
            return "claude-sonnet-4-0"
        case .openAI:
            return "gpt-5-mini"
        case .grok:
            return "grok-4"
        case .elevenLabs:
            return "scribe_v1"
        case .deepgram:
            return "whisper-1"
        case .openRouter:
            return "openai/gpt-oss-120b"
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .groq:
            return [
                "llama-3.3-70b-versatile",
                "moonshotai/kimi-k2-instruct-0905",
                "qwen/qwen3-32b",
                "meta-llama/llama-4-maverick-17b-128e-instruct",
                "openai/gpt-oss-120b"
            ]
        case .gemini:
            return [
                "gemini-2.5-pro",
                "gemini-2.5-flash",
                "gemini-2.5-flash-lite",
                "gemini-2.5-flash-preview-09-2025",
                "gemini-2.5-flash-lite-preview-09-2025",
                "gemini-2.0-flash",
                "gemini-2.0-flash-lite"
            ]
        case .anthropic:
            return [
                "claude-opus-4-0",
                "claude-sonnet-4-0",
                "claude-3-7-sonnet-latest",
                "claude-3-5-haiku-latest",
                "claude-3-5-sonnet-latest"
            ]
        case .openAI:
            return [
                "gpt-5",
                "gpt-5-mini",
                "gpt-5-nano",
                "gpt-4.1",
                "gpt-4.1-mini"
            ]
        case .grok:
            return [
                "grok-4",
                "grok-4-heavy",
                "grok-code-fast-1"
            ]
        case .elevenLabs:
            return ["scribe_v1", "scribe_v1_experimental"]
        case .deepgram:
            return ["whisper-1"]
        case .openRouter:
            return []
        }
    }
}
