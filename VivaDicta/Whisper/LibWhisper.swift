import Foundation
#if canImport(whisper)
    import whisper
#else
    #error("Unable to import whisper module. Please check your project configuration.")
#endif
import os

extension OpaquePointer: @unchecked Sendable {}

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
    private var context: OpaquePointer?
    private var languageCString: [CChar]?
    private var prompt: String?
    private var promptCString: [CChar]?
    private var vadModelPath: String?
    private var vadModelPathCString: [CChar]? // Persistent storage for VAD model path
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "WhisperContext")

    private init() {}

    init(context: OpaquePointer) {
        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    func fullTranscribe(samples: [Float]) -> Bool {
        guard let context = context else { return false }

        let maxThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)

        // Read language directly from shared UserDefaults (needs to be shared with keyboard)
        let sharedDefaults = UserDefaults(suiteName: "group.com.antonnovoselov.VivaDicta") ?? UserDefaults.standard
        let selectedLanguage = sharedDefaults.string(forKey: Constants.kSelectedLanguageKey) ?? "auto"
        if selectedLanguage != "auto" {
            languageCString = Array(selectedLanguage.utf8CString)
            params.language = languageCString?.withUnsafeBufferPointer { ptr in
                ptr.baseAddress
            }
        } else {
            languageCString = nil
            params.language = nil
        }

        if let prompt {
            promptCString = Array(prompt.utf8CString)
            params.initial_prompt = promptCString?.withUnsafeBufferPointer { ptr in
                ptr.baseAddress
            }
        } else {
            promptCString = nil
            params.initial_prompt = nil
        }

        params.print_realtime = true
        params.print_progress = false
        params.print_timestamps = true
        params.print_special = false
        params.translate = false
        params.n_threads = Int32(maxThreads)
        params.offset_ms = 0
        params.no_context = true
        params.single_segment = false
        params.temperature = 0.2

        whisper_reset_timings(context)

        // Configure VAD if enabled by user and model is available (shared setting)
        let isVADEnabled = sharedDefaults.object(forKey: "IsVADEnabled") as? Bool ?? true
        if isVADEnabled, let vadModelPath = vadModelPath {
            // Store the VAD model path as C string for persistence
            vadModelPathCString = Array(vadModelPath.utf8CString)

            params.vad = true
            params.vad_model_path = vadModelPathCString?.withUnsafeBufferPointer { ptr in
                ptr.baseAddress
            }

            var vadParams = whisper_vad_default_params()
            vadParams.threshold = 0.6
            vadParams.min_speech_duration_ms = 250
            vadParams.min_silence_duration_ms = 800
            vadParams.max_speech_duration_s = Float.greatestFiniteMagnitude
            vadParams.speech_pad_ms = 400
            vadParams.samples_overlap = 0.875
            params.vad_params = vadParams

            logger.info("VAD enabled with threshold: \(vadParams.threshold), min_silence: \(vadParams.min_silence_duration_ms)ms")
        } else {
            params.vad = false
            if !isVADEnabled {
                logger.info("VAD disabled by user preference")
            } else if vadModelPath == nil {
                logger.warning("VAD model not available despite being enabled")
            }
        }

        var success = true
        let startTime = Date()
        let vadEnabled = params.vad

        samples.withUnsafeBufferPointer { samplesBuffer in
            if whisper_full(context, params, samplesBuffer.baseAddress, Int32(samplesBuffer.count)) != 0 {
                logger.error("Failed to run whisper_full. VAD enabled: \(vadEnabled)")
                success = false
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)
        if vadEnabled {
            logger.info("Transcription with VAD completed in \(String(format: "%.2f", processingTime))s")
        }

        languageCString = nil
        promptCString = nil
        vadModelPathCString = nil

        return success
    }

    func getTranscription() -> String {
        guard let context = context else { return "" }
        var transcription = ""
        for i in 0 ..< whisper_full_n_segments(context) {
            transcription += String(cString: whisper_full_get_segment_text(context, i))
        }
        return transcription
    }

    static func createContext(path: String) async throws -> WhisperContext {
        let whisperContext = WhisperContext()
        try await whisperContext.initializeModel(path: path)

        // Load VAD model with proper error handling
        if let modelURL = Bundle.main.url(forResource: "ggml-silero-v5.1.2", withExtension: "bin") {
            // Verify the file exists and is readable
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: modelURL.path) {
                await whisperContext.setVADModelPath(modelURL.path)
                whisperContext.logger.info("VAD model loaded successfully from: \(modelURL.lastPathComponent)")
            } else {
                whisperContext.logger.error("VAD model file not found at expected path: \(modelURL.path)")
            }
        } else {
            whisperContext.logger.warning("VAD model 'ggml-silero-v5.1.2.bin' not found in bundle resources")
        }

        return whisperContext
    }

    private func initializeModel(path: String) throws {
        var params = whisper_context_default_params()
        #if targetEnvironment(simulator)
            params.use_gpu = false
            logger.info("Running on the simulator, using CPU")
        #else
            params.flash_attn = true // Enable flash attention for Metal
            logger.info("Flash attention enabled for Metal")
        #endif

        let context = whisper_init_from_file_with_params(path, params)
        if let context {
            self.context = context
        } else {
            logger.error("Couldn't load model at \(path)")
            throw WhisperStateError.modelLoadFailed
        }
    }

    private func setVADModelPath(_ path: String?) {
        vadModelPath = path
        if let path = path {
            // Verify model file size to ensure it's valid
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let fileSize = attributes[.size] as? Int64
            {
                let sizeMB = Double(fileSize) / (1024 * 1024)
                logger.info("VAD model loaded: \(String(format: "%.2f", sizeMB))MB")
            }
        } else {
            logger.warning("VAD model path is nil")
        }
    }

    func releaseResources() {
        if let context = context {
            whisper_free(context)
            self.context = nil
        }
        languageCString = nil
        promptCString = nil
        vadModelPathCString = nil
    }

    func setPrompt(_ prompt: String?) {
        self.prompt = prompt
    }
}
