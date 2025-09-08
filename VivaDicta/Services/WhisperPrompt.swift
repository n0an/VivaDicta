//
//  WhisperPrompt.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.04
//

import Foundation

class WhisperPrompt {
    private var transcriptionPrompt: String = UserDefaults.standard.string(forKey: Constants.kTranscriptionPrompt) ?? ""
    
    private var customPrompts: [String: String] = [:]
    
    init() {
        loadCustomPrompts()
        updateTranscriptionPrompt()
    }
    
    public func updateTranscriptionPrompt() {
        let selectedLanguage = UserDefaults.standard.string(forKey: Constants.kSelectedLanguageKey) ?? "en"
        let prompt = getLanguagePrompt(for: selectedLanguage)
        transcriptionPrompt = prompt
        UserDefaults.standard.set(prompt, forKey: Constants.kTranscriptionPrompt)
        UserDefaults.standard.synchronize()
    }
    
    private func getLanguagePrompt(for language: String) -> String {
        if let customPrompt = customPrompts[language], !customPrompt.isEmpty {
            return customPrompt
        }
        
        return defaultLanguagePrompts[language] ?? ""
    }
    
    // MARK: - Custom Prompts
    public func setCustomPrompt(_ prompt: String, for language: String) {
        customPrompts[language] = prompt
        saveCustomPrompts()
        updateTranscriptionPrompt()
    }
    
    private func loadCustomPrompts() {
        if let savedPrompts = UserDefaults.standard.dictionary(forKey: Constants.customPromptsKey) as? [String: String] {
            customPrompts = savedPrompts
        }
    }
    
    private func saveCustomPrompts() {
        UserDefaults.standard.set(customPrompts, forKey: Constants.customPromptsKey)
        UserDefaults.standard.synchronize()
    }
    
    
    // Language-specific base prompts
    private let defaultLanguagePrompts: [String: String] = [
        // English
        "en": "I wanted to follow up on our meeting from yesterday and discuss the project timeline. The key points we covered include the budget allocation and resource planning. Please let me know if you need any additional information or have questions about the next steps.",
        
        // Asian Languages
        "hi": "मैं कल की बैठक के बारे में बात करना चाहता था। हमने प्रोजेक्ट की समयसीमा और बजट के बारे में चर्चा की थी। कृपया बताएं कि क्या आपको कोई अतिरिक्त जानकारी चाहिए।",
        "bn": "আমি গতকালের মিটিং সম্পর্কে কথা বলতে চাইছিলাম। আমরা প্রকল্পের সময়সূচী এবং বাজেট নিয়ে আলোচনা করেছিলাম। দয়া করে জানান যদি আপনার কোনো অতিরিক্ত তথ্যের প্রয়োজন হয়।",
        "ja": "昨日の会議について話したいと思います。プロジェクトのスケジュールと予算について話し合いました。追加情報が必要でしたら教えてください。",
        "ko": "어제 회의에 대해 이야기하고 싶었습니다. 프로젝트 일정과 예산에 대해 논의했습니다. 추가 정보가 필요하시면 알려주세요.",
        "zh": "我想谈谈昨天的会议内容。我们讨论了项目时间表和预算分配。如果您需要任何额外信息，请告诉我。",
        "th": "ผมอยากพูดเรื่องการประชุมเมื่อวานนี้ เราได้หารือเกี่ยวกับกำหนดเวลาโครงการและงบประมาณ กรุณาแจ้งหากต้องการข้อมูลเพิ่มเติม",
        "vi": "Tôi muốn thảo luận về cuộc họp hôm qua. Chúng ta đã bàn về tiến độ dự án và ngân sách. Xin cho biết nếu cần thêm thông tin.",
        "yue": "我想講吓昨日嘅會議。我哋討論咗項目時間表同預算分配。如果你需要額外資訊，請話俾我知。",
        
        // European Languages
        "es": "Quería hacer un seguimiento de nuestra reunión de ayer sobre el proyecto. Discutimos los plazos y la asignación del presupuesto. Por favor avísame si necesitas información adicional.",
        "fr": "Je voulais faire le point sur notre réunion d'hier concernant le projet. Nous avons discuté des délais et de l'allocation budgétaire. Merci de me faire savoir si vous avez besoin d'informations supplémentaires.",
        "de": "Ich wollte unser gestriges Meeting zum Projekt nachbereiten. Wir haben über Zeitpläne und Budgetzuteilung gesprochen. Bitte lassen Sie mich wissen, wenn Sie zusätzliche Informationen benötigen.",
        "it": "Volevo fare il punto sulla nostra riunione di ieri riguardo al progetto. Abbiamo discusso delle tempistiche e dell'allocazione del budget. Per favore fatemi sapere se avete bisogno di informazioni aggiuntive.",
        "pt": "Queria fazer um acompanhamento da nossa reunião de ontem sobre o projeto. Discutimos os prazos e a alocação do orçamento. Por favor me avisem se precisarem de informações adicionais.",
        "ru": "Я хотел обсудить вчерашнее совещание по проекту. Мы говорили о временных рамках и распределении бюджета. Пожалуйста, сообщите, если вам нужна дополнительная информация.",
        "pl": "Chciałem omówić wczorajsze spotkanie dotyczące projektu. Rozmawialiśmy o harmonogramie i alokacji budżetu. Proszę daj mi znać, jeśli potrzebujesz dodatkowych informacji.",
        "nl": "Ik wilde onze gisteren vergadering over het project bespreken. We hebben gepraat over tijdschema's en budgetallocatie. Laat me weten als je aanvullende informatie nodig hebt.",
        "tr": "Dünkü proje toplantımızı takip etmek istiyordum. Zaman çizelgesi ve bütçe dağılımı hakkında konuştuk. Ek bilgiye ihtiyacın varsa lütfen bana haber ver.",
        
        // Middle Eastern Languages
        "ar": "مرحباً، كيف حالك؟ سعيد بلقائك.",
        "fa": "سلام، حال شما چطور است؟ از آشنایی با شما خوشوقتم.",
        "he": ",שלום, מה שלומך? נעים להכיר",
        
        // South Asian Languages
        "ta": "நேற்றைய கூட்டத்தைப் பற்றி விவாதிக்க வேண்டும். நாங்கள் திட்ட அட்டவணை மற்றும் வரவுசெலவுத் திட்டத்தைப் பற்றிப் பேசினோம். கூடுதல் தகவல்கள் தேவை என்றால் சொல்லுங்கள்.",
        "te": "నేను నిన్నటి ప్రాజెక్ట్ మీటింగ్ గురించి మాట్లాడాలని అనుకున్నాను. మేము సమయపరిమితి మరియు బడ్జెట్ కేటాయింపు గురించి చర్చించాము. అదనపు వివరాలు కావాలంటే దయచేసి చెప్పండి.",
        "ml": "ഇന്നലെ നടന്ന പ്രോജക്റ്റ് മീറ്റിംഗിനെക്കുറിച്ച് സംസാരിക്കണമെന്ന് തോന്നുന്നു. ഞങ്ങൾ സമയക്രമത്തെയും ബജറ്റ് വിഭജനത്തെയും കുറിച്ച് ചർച്ച ചെയ്തു. അധിക വിവരങ്ങൾ വേണമെങ്കിൽ അറിയിക്കുക.",
        "kn": "ನಿನ್ನೆಯ ಪ್ರೋಜೆಕ್ಟ್ ಸಭೆಯ ಬಗ್ಗೆ ಮಾತನಾಡಬೇಕಾಗಿದೆ. ನಾವು ಸಮಯ ಪಟ್ಟಿ ಮತ್ತು ಬಜೆಟ್ ಹಂಚಿಕೆಯ ಬಗ್ಗೆ ಚರ್ಚಿಸಿದ್ದೇವೆ. ನಿಮಗೆ ಹೆಚ್ಚು ಮಾಹಿತಿ ಬೇಕಾದರೆ ದಯವಿಟ್ಟು ತಿಳಿಸಿ.",
        "ur": "میں کل کی پروجیکٹ میٹنگ کے بارے میں بات کرنا چاہتا ہوں۔ ہم نے وقت کے شیڈول اور بجٹ کی تقسیم پر بحث کی تھی۔ اگر آپ کو مزید معلومات درکار ہوں تو برائے کرم بتائیں۔",
        
        // Default prompt for unsupported languages
        "default": ""
    ]
}
