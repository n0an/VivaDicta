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
    
    var whisperContext: WhisperContext?
    var currentTranscriptionModel: (any TranscriptionModel)?

    
    var allAvailableModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
    
    
    
    var availableWhisperLocalModels: [WhisperLocalModel] {
        TranscriptionModelProvider.allLocalModels.filter { $0.fileExists }
    }
    
    var localTranscriptionService: LocalTranscriptionService!
    private var cloudTranscriptionService = CloudTranscriptionService()
    
    
    
    let whisperPrompt = WhisperPrompt()
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    var selectedTab: TabTag = .record
    var transcriptionService: (any TranscriptionService)?
    
//    var canTranscribe: Bool {
//        transcriptionService != nil
//    }
    
    
    var allLocalModels = TranscriptionModelProvider.allLocalModels
    var allCloudModels = TranscriptionModelProvider.allCloudModels
    
    var transcriptionModelSelected = false
    
    var selectedLocalWhisperModel: WhisperLocalModel? {
        didSet {
            if selectedLocalWhisperModel != nil {
                transcriptionModelSelected = true
            } else {
                transcriptionModelSelected = selectedCloudModel != nil
            }
        }
    }
    
    var selectedCloudModel: CloudModel? {
        didSet {
            if selectedCloudModel != nil {
                transcriptionModelSelected = true
            } else {
                transcriptionModelSelected = selectedLocalWhisperModel != nil
            }
        }
    }
    
//    var selectedLanguage: Language = .auto {
//        didSet {
//            setLanguage(selectedLanguage)
//        }
//    }
    
    init() {
        if let selectedModelName = UserDefaults.standard.string(forKey: kSelectedWhisperLocalModel),
           let selectedModel = allLocalModels.first(where: {$0.name == selectedModelName}) {
            self.selectedLocalWhisperModel = selectedModel
            self.createLocalTranscriber(model: selectedModel)
        } else if let selectedModelName = UserDefaults.standard.string(forKey: kSelectedCloudModel),
                  let selectedModel = allCloudModels.first(where: {$0.name == selectedModelName}) {
            self.selectedCloudModel = selectedModel
            self.createCloudTranscriber(model: selectedModel)
        }
        
//        if let selectedLanguageKey = UserDefaults.standard.string(forKey: kSelectedLanguageKey),
//           let savedSelectedLanguage = Language(rawValue: selectedLanguageKey) {
//            self.selectedLanguage = savedSelectedLanguage
//        }
        
        
        localTranscriptionService = LocalTranscriptionService(appState: self)

        
    }
    
    
    
    
    func transcribe(audioURL: URL) async throws -> String {
        guard let model = currentTranscriptionModel else {
            throw WhisperStateError.transcriptionFailed
        }

        let transcriptionService: any TranscriptionService
        switch model.provider {
        case .local:
            transcriptionService = localTranscriptionService
        case .parakeet:
            transcriptionService = localTranscriptionService

//            transcriptionService = parakeetTranscriptionService
//            transcriptionService = nativeAppleTranscriptionService
        default:
            transcriptionService = cloudTranscriptionService
        }

        let transcriptionStart = Date()
        var text = try await transcriptionService.transcribe(audioURL: audioURL, model: model)
        let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)
        return text
    }
    
    
    
    
    
    
    
    func loadModel(_ model: WhisperLocalModel) async throws {
        guard whisperContext == nil else { return }

        do {
            whisperContext = try await WhisperContext.createContext(path: model.fileURL.path)

            // Set the prompt from UserDefaults to ensure we have the latest
            let currentPrompt = UserDefaults.standard.string(forKey: kTranscriptionPrompt) ?? whisperPrompt.transcriptionPrompt
            await whisperContext?.setPrompt(currentPrompt)

        } catch {
            throw WhisperStateError.modelLoadFailed
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
//    func setLanguage(_ language: Language) {
////        self.transcriptionService?.selectedLanguage = language
//        UserDefaults.standard.set(language.rawValue, forKey: kSelectedLanguageKey)
//    }
    
    func updateCloudModels(with model: CloudModel, apiKey: String) {
        CloudModel.saveApiKey(apiKey, modelName: model.name)
        allCloudModels = TranscriptionModelProvider.allCloudModels
    }
    
    func createLocalTranscriber(model: WhisperLocalModel) {
        selectedLocalWhisperModel = model
        selectedCloudModel = nil
//        transcriptionService = LocalWhisperTranscriptionService(selectedModel: model, selectedLanguage: self.selectedLanguage)
        UserDefaults.standard.set(model.name, forKey: kSelectedWhisperLocalModel)
        UserDefaults.standard.set(nil, forKey: kSelectedCloudModel)
    }
    
    func createCloudTranscriber(model: CloudModel) {
        selectedCloudModel = model
        selectedLocalWhisperModel = nil
//        transcriptionService = LocalWhisperTranscriptionService(selectedModel: model, selectedLanguage: self.selectedLanguage)
        UserDefaults.standard.set(model.name, forKey: kSelectedCloudModel)
        UserDefaults.standard.set(nil, forKey: kSelectedWhisperLocalModel)
    }
}

// MARK: - Global
enum TabTag {
    case record
    case transcriptions
    case models
    case settings
}

//enum Language: String, CaseIterable, Identifiable {
//    var id: Self { self }
//    case auto = "Auto Detect"
//    case en
//    case ru
//    
//    var fullName: String {
//        switch self {
//        case .auto:
//            "Auto Detect"
//        case .en:
//            "English"
//        case .ru:
//            "Russian"
//        }
//    }
//    
//    var prompt: String {
//        let languagePrompts = [
//            // English
//            "en": "Hello, how are you doing? Nice to meet you.",
//            
//            // Asian Languages
//            "hi": "नमस्ते, कैसे हैं आप? आपसे मिलकर अच्छा लगा।",
//            "bn": "নমস্কার, কেমন আছেন? আপনার সাথে দেখা হয়ে ভালো লাগলো।",
//            "ja": "こんにちは、お元気ですか？お会いできて嬉しいです。",
//            "ko": "안녕하세요, 잘 지내시나요? 만나서 반갑습니다.",
//            "zh": "你好，最近好吗？见到你很高兴。",
//            "th": "สวัสดีครับ/ค่ะ, สบายดีไหม? ยินดีที่ได้พบคุณ",
//            "vi": "Xin chào, bạn khỏe không? Rất vui được gặp bạn.",
//            "yue": "你好，最近點呀？見到你好開心。",
//            
//            // European Languages
//            "es": "¡Hola, ¿cómo estás? Encantado de conocerte.",
//            "fr": "Bonjour, comment allez-vous? Ravi de vous rencontrer.",
//            "de": "Hallo, wie geht es dir? Schön dich kennenzulernen.",
//            "it": "Ciao, come stai? Piacere di conoscerti.",
//            "pt": "Olá, como você está? Prazer em conhecê-lo.",
//            "ru": "Здравствуйте, как ваши дела? Приятно познакомиться.",
//            "pl": "Cześć, jak się masz? Miło cię poznać.",
//            "nl": "Hallo, hoe gaat het? Aangenaam kennis te maken.",
//            "tr": "Merhaba, nasılsın? Tanıştığımıza memnun oldum.",
//            
//            // Middle Eastern Languages
//            "ar": "مرحباً، كيف حالك؟ سعيد بلقائك.",
//            "fa": "سلام، حال شما چطور است؟ از آشنایی با شما خوشوقتم.",
//            "he": ",שלום, מה שלומך? נעים להכיר",
//            
//            // South Asian Languages
//            "ta": "வணக்கம், எப்படி இருக்கிறீர்கள்? உங்களை சந்தித்ததில் மகிழ்ச்சி.",
//            "te": "నమస్కారం, ఎలా ఉన్నారు? కలవడం చాలా సంతోషం.",
//            "ml": "നമസ്കാരം, സുഖമാണോ? കണ്ടതിൽ സന്തോഷം.",
//            "kn": "ನಮಸ್ಕಾರ, ಹೇಗಿದ್ದೀರಾ? ನಿಮ್ಮನ್ನು ಭೇಟಿಯಾಗಿ ಸಂತೋಷವಾಗಿದೆ.",
//            "ur": "السلام علیکم، کیسے ہیں آپ؟ آپ سے مل کر خوشی ہوئی۔",
//            
//            // Default prompt for unsupported languages
//            "default": ""
//        ]
//        
//        return languagePrompts[self.rawValue] ?? "Hello, how are you doing? Nice to meet you."
//    }
//}



extension AppState {
    func loadCurrentTranscriptionModel() {
        if let savedModelName = UserDefaults.standard.string(forKey: "CurrentTranscriptionModel"),
           let savedModel = allAvailableModels.first(where: { $0.name == savedModelName }) {
            currentTranscriptionModel = savedModel
        }
    }

    // Function to set any transcription model as default
    func setDefaultTranscriptionModel(_ model: any TranscriptionModel) {
        self.currentTranscriptionModel = model
        UserDefaults.standard.set(model.name, forKey: "CurrentTranscriptionModel")
        
        if model.provider == .local, let localWhipserModel = model as? WhisperLocalModel {
            Task { try await loadModel(localWhipserModel) }
        }
        
        // Post notification about the model change
//        NotificationCenter.default.post(name: .didChangeModel, object: nil, userInfo: ["modelName": model.name])
//        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
}
