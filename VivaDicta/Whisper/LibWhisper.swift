import Foundation
import UIKit
import whisper

enum WhisperError: Error {
    case couldNotInitializeContext
}

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
    private var context: OpaquePointer
    private var languageCString: [CChar]?
    private var prompt: String?
    private var promptCString: [CChar]?
    private var vadModelPath: String?

    init(context: OpaquePointer) {
        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    func fullTranscribe(samples: [Float]) -> Bool {
        // Leave 2 processors free (i.e. the high-efficiency cores).
        let maxThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        print("Selecting \(maxThreads) threads")
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        
        // Read language directly from UserDefaults
        let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "ru"
        if selectedLanguage != "auto" {
            languageCString = Array(selectedLanguage.utf8CString)
            params.language = languageCString?.withUnsafeBufferPointer { ptr in
                ptr.baseAddress
            }
        } else {
            languageCString = nil
            params.language = nil
        }
        
        if true  || prompt != nil {
            promptCString = Array("Здравствуйте, как ваши дела? Приятно познакомиться.".utf8CString)
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
        
        var success = true
        samples.withUnsafeBufferPointer { samplesBuffer in
            if whisper_full(context, params, samplesBuffer.baseAddress, Int32(samplesBuffer.count)) != 0 {
                print("Failed to run whisper_full.")
                success = false
            } else {
                whisper_print_timings(context)
            }
        }
        
        languageCString = nil
        promptCString = nil
        
        return success
    }

    func getTranscription() -> String {
        var transcription = ""
        for i in 0..<whisper_full_n_segments(context) {
            transcription += String.init(cString: whisper_full_get_segment_text(context, i))
        }
        return transcription
    }
    
    static func createContext(path: String) throws -> WhisperContext {
        var params = whisper_context_default_params()
#if targetEnvironment(simulator)
        params.use_gpu = false
        print("Running on the simulator, using CPU")
#else
        params.flash_attn = true // Enabled by default for Metal
#endif
        let context = whisper_init_from_file_with_params(path, params)
        if let context {
            return WhisperContext(context: context)
        } else {
            print("Couldn't load model at \(path)")
            throw WhisperError.couldNotInitializeContext
        }
    }
    
    func setPrompt(_ prompt: String?) {
        self.prompt = prompt
    }
}
