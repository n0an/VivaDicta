//
//  StreamingAudioCapture.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.08.08
//

import AVFoundation
import AppGroup
import Foundation
import os

/// Records to a WAV file *and* hands out the same PCM as a live stream.
///
/// `AVAudioRecorder` (the normal dictation recorder) exposes no buffer
/// callbacks, so realtime streaming needs an engine-backed capture. Rather
/// than migrate the default path - which every user and every provider goes
/// through - this is a parallel implementation used only when a streaming
/// model is selected. The file it writes is what the upload-and-poll fallback
/// and normal storage/playback use, so nothing downstream has to care which
/// capture produced it.
@MainActor
final class StreamingAudioCapture {
    /// Matches what the file-based recorder writes and what Soniox realtime
    /// expects (`pcm_s16le` @ 16 kHz mono), so no second conversion is needed.
    static let sampleRate: Double = 16_000

    enum CaptureError: LocalizedError {
        case sessionFailure(String)
        case engineFailure(String)

        var errorDescription: String? {
            switch self {
            case .sessionFailure(let message): "Audio session failed: \(message)"
            case .engineFailure(let message): "Audio engine failed: \(message)"
            }
        }
    }

    private let logger = Logger(category: .streamingAudioCapture)
    private let engine = AVAudioEngine()

    private var continuation: AsyncStream<Data>.Continuation?
    private var sink: CaptureSink?
    private var isStarted = false
    private var tapInstalled = false
    private var sessionActivated = false

    private let captureFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: StreamingAudioCapture.sampleRate,
            channels: 1,
            interleaved: true
        )!
    }()

    /// Normalised 0...1 mic level for the waveform, mirroring what the
    /// `AVAudioRecorder` path feeds the visualizer. Read from MainActor while
    /// the tap writes it on the audio thread, so it goes through the sink's lock.
    var currentAudioLevel: Float {
        sink?.currentLevel ?? 0
    }

    /// Bounded so a stalled WebSocket drops old audio instead of growing
    /// memory without limit. ~50 chunks of ~20ms is about a second of slack.
    func makeStream() -> AsyncStream<Data> {
        AsyncStream<Data>(bufferingPolicy: .bufferingNewest(50)) { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in self?.continuation = nil }
            }
        }
    }

    func start(writingTo url: URL) async throws {
        guard !isStarted else { return }

        do {
            try configureSession()
            try await configureEngine(writingTo: url)
            try engine.start()
            isStarted = true
        } catch {
            await stop()
            throw error
        }
    }

    /// Idempotent. Teardown runs off MainActor because `engine.stop()` and
    /// `removeTap` can block for a noticeable moment after a route change, and
    /// blocking MainActor there freezes the stop button.
    func stop() async {
        guard isStarted || tapInstalled || sessionActivated else { return }

        let needsTap = tapInstalled
        let needsDeactivate = sessionActivated

        isStarted = false
        tapInstalled = false
        sessionActivated = false

        let continuation = self.continuation
        self.continuation = nil

        let context = StreamingTeardownContext(
            engine: engine,
            sink: sink,
            removeTap: needsTap,
            deactivateSession: needsDeactivate,
            logger: logger
        )
        sink = nil

        // Silence the producer BEFORE closing the stream. Finishing first
        // leaves a window where an in-flight tap callback still writes its
        // buffer to the WAV but yields into an already-terminated stream - the
        // socket would then return a successful transcript quietly missing that
        // audio, with nothing to trigger the upload fallback.
        await Task(priority: .userInitiated) { @concurrent in
            context.perform()
        }.value

        continuation?.finish()
    }

    // MARK: - Private

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: RecordingAudioSession.categoryOptions(base: [.defaultToSpeaker])
            )
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: [])
            sessionActivated = true
            RecordingAudioSession.applyPreferredInput(to: session)
        } catch {
            throw CaptureError.sessionFailure(error.localizedDescription)
        }
    }

    private func configureEngine(writingTo url: URL) async throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw CaptureError.engineFailure("invalid input format")
        }

        guard let continuation else {
            throw CaptureError.engineFailure("capture stream not initialized")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: captureFormat) else {
            throw CaptureError.engineFailure("converter init failed")
        }

        // Write a real 16-bit PCM WAV so the fallback upload, playback, and
        // retranscription all see the same file shape the normal recorder makes.
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: fileSettings, commonFormat: .pcmFormatInt16, interleaved: true)
        } catch {
            throw CaptureError.engineFailure("audio file open failed: \(error.localizedDescription)")
        }

        let sink = CaptureSink(
            converter: converter,
            captureFormat: captureFormat,
            audioFile: audioFile,
            continuation: continuation
        )
        self.sink = sink

        // Install from a background queue so the tap closure does not inherit
        // MainActor isolation - AVAudioEngine calls it on its realtime thread
        // and an isolated closure trips _dispatch_assert_queue_fail.
        //
        // This is the one deliberate exception to the repo's no-GCD rule, and
        // it matches what `LiveTranslationAudio.configureEngine` and
        // `AudioPrewarmManager` already do for the same reason. A structured
        // alternative that reliably strips the isolation from a closure handed
        // to a C-level realtime callback does not exist today; swapping in a
        // Task here reintroduces the crash those two call sites solved.
        await withCheckedContinuation { resume in
            DispatchQueue.global(qos: .userInitiated).async {
                installStreamingInputTap(inputNode: inputNode, format: inputFormat, sink: sink)
                resume.resume()
            }
        }
        tapInstalled = true

        engine.prepare()
    }
}

/// Hardware-side teardown, wrapped in an `@unchecked Sendable` class so it can
/// run off MainActor. Mirrors `LiveTranslationAudio`'s teardown, including its
/// hard-won detail: deactivate the session WITHOUT
/// `.notifyOthersOnDeactivation`, which fires synchronous notifications to
/// other apps and has been observed to take seconds.
nonisolated private final class StreamingTeardownContext: @unchecked Sendable {
    private let engine: AVAudioEngine
    private let sink: CaptureSink?
    private let removeTap: Bool
    private let deactivateSession: Bool
    private let logger: Logger

    init(
        engine: AVAudioEngine,
        sink: CaptureSink?,
        removeTap: Bool,
        deactivateSession: Bool,
        logger: Logger
    ) {
        self.engine = engine
        self.sink = sink
        self.removeTap = removeTap
        self.deactivateSession = deactivateSession
        self.logger = logger
    }

    func perform() {
        if removeTap {
            engine.inputNode.removeTap(onBus: 0)
        }

        engine.stop()

        // Close after the tap is gone so no write can be in flight.
        sink?.closeFile()

        if deactivateSession {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                logger.logWarning("Streaming capture: session deactivate failed: \(error.localizedDescription)")
            }
        }
    }
}

/// Installs the tap from a nonisolated context so the closure stays free of
/// MainActor isolation.
nonisolated private func installStreamingInputTap(
    inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    sink: CaptureSink
) {
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
        sink.process(buffer)
    }
}

/// Runs entirely on AVAudioEngine's realtime audio thread. Converts each input
/// buffer once, then fans the result out to both the file and the socket -
/// converting twice would be wasted work on a thread that must not stall.
nonisolated private final class CaptureSink: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let captureFormat: AVAudioFormat
    private let continuation: AsyncStream<Data>.Continuation
    private let lock = NSLock()
    private var audioFile: AVAudioFile?
    private var level: Float = 0

    var currentLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return level
    }

    init(
        converter: AVAudioConverter,
        captureFormat: AVAudioFormat,
        audioFile: AVAudioFile,
        continuation: AsyncStream<Data>.Continuation
    ) {
        self.converter = converter
        self.captureFormat = captureFormat
        self.audioFile = audioFile
        self.continuation = continuation
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        let sourceFormat = buffer.format
        let ratio = captureFormat.sampleRate / sourceFormat.sampleRate
        let estimatedFrames = Double(buffer.frameLength) * ratio
        let outCapacity = AVAudioFrameCount(estimatedFrames.rounded(.up)) + 1024

        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: captureFormat, frameCapacity: outCapacity) else {
            return
        }

        var providedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outBuffer, error: &conversionError) { _, statusPtr in
            if providedInput {
                statusPtr.pointee = .noDataNow
                return nil
            }
            providedInput = true
            statusPtr.pointee = .haveData
            return buffer
        }

        if status == .error || conversionError != nil {
            return
        }

        guard outBuffer.frameLength > 0, let channelData = outBuffer.int16ChannelData else {
            return
        }

        let frameCount = Int(outBuffer.frameLength)
        let meterLevel = Self.normalizedLevel(samples: channelData[0], frameCount: frameCount)

        lock.lock()
        try? audioFile?.write(from: outBuffer)
        level = meterLevel
        lock.unlock()

        continuation.yield(Data(bytes: channelData[0], count: frameCount * 2))
    }

    /// RMS of the Int16 samples mapped onto 0...1 with a dB curve, so the
    /// waveform responds like it does on the `AVAudioRecorder` path rather
    /// than sitting near zero for normal speech.
    private static func normalizedLevel(samples: UnsafeMutablePointer<Int16>, frameCount: Int) -> Float {
        guard frameCount > 0 else { return 0 }

        var sumOfSquares: Float = 0
        for index in 0..<frameCount {
            let sample = Float(samples[index]) / Float(Int16.max)
            sumOfSquares += sample * sample
        }

        let rms = (sumOfSquares / Float(frameCount)).squareRoot()
        guard rms > 0 else { return 0 }

        let decibels = 20 * log10(rms)
        return min(1, max(0, 1 - abs(decibels / 50)))
    }

    /// AVAudioFile finalises its header on deallocation, so dropping the
    /// reference under the same lock the tap uses is what closes the WAV
    /// cleanly without racing an in-flight write.
    func closeFile() {
        lock.lock()
        audioFile = nil
        lock.unlock()
    }
}
