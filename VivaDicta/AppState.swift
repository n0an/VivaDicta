//
//  AppState.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import SwiftUI


@Observable
class AppState {
    
    // MARK: - UI State
    var selectedTab: TabTag = .record
    
    // MARK: - Managers
    let settingsManager: SettingsManager
    let modelManager: ModelManager
    let transcriptionManager: TranscriptionManager
    
    // MARK: - Computed Properties
    
    var canTranscribe: Bool {
        transcriptionManager.canTranscribe && modelManager.hasSelectedModel
    }
    
    var selectedLanguage: Language {
        get { transcriptionManager.selectedLanguage }
        set { transcriptionManager.setLanguage(newValue) }
    }
    
    var selectedLocalWhisperModel: WhisperModel? {
        modelManager.selectedModel
    }
    
    // MARK: - Initialization
    
    init(settingsManager: SettingsManager? = nil,
         modelManager: ModelManager? = nil,
         transcriptionManager: TranscriptionManager? = nil) {
        
        // Create or use provided managers
        let settings = settingsManager ?? SettingsManager()
        let models = modelManager ?? ModelManager(settingsManager: settings)
        let transcription = transcriptionManager ?? TranscriptionManager(settingsManager: settings)
        
        self.settingsManager = settings
        self.modelManager = models
        self.transcriptionManager = transcription
        
        // Initialize transcriber if model is available
        if let selectedModel = models.selectedModel, selectedModel.fileExists {
            transcription.createLocalTranscriber(with: selectedModel)
        }
    }
    
    // MARK: - Convenience Methods
    
    func createTranscriber(model: WhisperModel) {
        guard modelManager.selectModel(model) else { return }
        transcriptionManager.createLocalTranscriber(with: model)
    }
    
    func setLanguage(_ language: Language) {
        transcriptionManager.setLanguage(language)
    }
    
    // MARK: - Transcription Access
    
    var transcriptionService: (any TranscriptionService)? {
        transcriptionManager.transcriptionService
    }
}

// MARK: - Global
enum TabTag {
    case record
    case transcriptions
    case models
    case settings
}

enum Language: String, CaseIterable, Identifiable {
    var id: Self { self }
    case auto = "Auto Detect"
    case en
    case ru
    
    var fullName: String {
        switch self {
        case .auto:
            "Auto Detect"
        case .en:
            "English"
        case .ru:
            "Russian"
        }
    }
    
    var prompt: String {
        let languagePrompts = [
            // English
            "en": "Hello, how are you doing? Nice to meet you.",
            
            // Asian Languages
            "hi": "नमस्ते, कैसे हैं आप? आपसे मिलकर अच्छा लगा।",
            "bn": "নমস্কার, কেমন আছেন? আপনার সাথে দেখা হয়ে ভালো লাগলো।",
            "ja": "こんにちは、お元気ですか？お会いできて嬉しいです。",
            "ko": "안녕하세요, 잘 지내시나요? 만나서 반갑습니다.",
            "zh": "你好，最近好吗？见到你很高兴。",
            "th": "สวัสดีครับ/ค่ะ, สบายดีไหม? ยินดีที่ได้พบคุณ",
            "vi": "Xin chào, bạn khỏe không? Rất vui được gặp bạn.",
            "yue": "你好，最近點呀？見到你好開心。",
            
            // European Languages
            "es": "¡Hola, ¿cómo estás? Encantado de conocerte.",
            "fr": "Bonjour, comment allez-vous? Ravi de vous rencontrer.",
            "de": "Hallo, wie geht es dir? Schön dich kennenzulernen.",
            "it": "Ciao, come stai? Piacere di conoscerti.",
            "pt": "Olá, como você está? Prazer em conhecê-lo.",
            "ru": "Здравствуйте, как ваши дела? Приятно познакомиться.",
            "pl": "Cześć, jak się masz? Miło cię poznać.",
            "nl": "Hallo, hoe gaat het? Aangenaam kennis te maken.",
            "tr": "Merhaba, nasılsın? Tanıştığımıza memnun oldum.",
            
            // Middle Eastern Languages
            "ar": "مرحباً، كيف حالك؟ سعيد بلقائك.",
            "fa": "سلام، حال شما چطور است؟ از آشنایی با شما خوشوقتم.",
            "he": ",שלום, מה שלומך? נעים להכיר",
            
            // South Asian Languages
            "ta": "வணக்கம், எப்படி இருக்கிறீர்கள்? உங்களை சந்தித்ததில் மகிழ்ச்சி.",
            "te": "నమస్కారం, ఎలా ఉన్నారు? కలవడం చాలా సంతోషం.",
            "ml": "നമസ്കാരം, സുഖമാണോ? കണ്ടതിൽ സന്തോഷം.",
            "kn": "ನಮಸ್ಕಾರ, ಹೇಗಿದ್ದೀರಾ? ನಿಮ್ಮನ್ನು ಭೇಟಿಯಾಗಿ ಸಂತೋಷವಾಗಿದೆ.",
            "ur": "السلام علیکم، کیسے ہیں آپ؟ آپ سے مل کر خوشی ہوئی۔",
            
            // Default prompt for unsupported languages
            "default": ""
        ]
        
        return languagePrompts[self.rawValue] ?? "Hello, how are you doing? Nice to meet you."
    }
}
