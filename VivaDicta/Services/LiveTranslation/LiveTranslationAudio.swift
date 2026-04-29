//
//  LiveTranslationAudio.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.28
//

import AVFoundation
import Foundation
import os

@MainActor
final class LiveTranslationAudio {
    static let captureSampleRate: Double = 16000
    static let playbackSampleRate: Double = SonioxRealtimeTTSClient.outputSampleRate

    private let logger = Logger(category: .liveTranslationAudio)
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let varispeedNode = AVAudioUnitVarispeed()
    private let bufferQueue = PlaybackBufferQueue()

    /// Playback rate applied via AVAudioUnitVarispeed. Russian/translated text
    /// usually runs longer than the source, so we play back faster than 1.0
    /// to keep the buffer queue from growing. Adjustable live; takes effect
    /// immediately whether the engine is running or not.
    var playbackRate: Float = LiveTranslationPreferences.defaultTTSRate {
        didSet {
            varispeedNode.rate = playbackRate
        }
    }

    private var captureContinuation: AsyncStream<Data>.Continuation?
    private var isStarted = false
    private var tapInstaller: TapInstaller?
    /// Tracks whether configureSession() activated AVAudioSession so partial
    /// startup failures still deactivate it on cleanup.
    private var sessionActivated = false
    /// Tracks whether the input tap was actually installed (separate from
    /// `tapInstaller != nil` because the install runs on a global queue).
    private var tapInstalled = false

    private let captureFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: LiveTranslationAudio.captureSampleRate,
            channels: 1,
            interleaved: true
        )!
    }()

    private let playbackFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: LiveTranslationAudio.playbackSampleRate,
            channels: 1,
            interleaved: false
        )!
    }()

    init() {
        // Attach + connect once per lifetime. Repeated start/stop cycles must NOT
        // re-attach nodes; AVAudioEngine throws on duplicate attach. The graph
        // stays intact across stop()/start(); we only stop/start the engine and
        // re-install the input tap.
        engine.attach(playerNode)
        engine.attach(varispeedNode)
        varispeedNode.rate = playbackRate
        engine.connect(playerNode, to: varispeedNode, format: playbackFormat)
        engine.connect(varispeedNode, to: engine.mainMixerNode, format: playbackFormat)
    }

    func makeCaptureStream() -> AsyncStream<Data> {
        // Bound the buffer so a slow STT WS doesn't pile up audio in memory.
        // 50 chunks at ~20ms each ≈ 1 second of headroom; older chunks are
        // dropped under backpressure rather than growing latency unboundedly.
        AsyncStream<Data>(bufferingPolicy: .bufferingNewest(50)) { continuation in
            captureContinuation = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.captureContinuation = nil
                }
            }
        }
    }

    func start() async throws {
        guard !isStarted else { return }

        // If any step throws, call stop() to clean up anything we already
        // activated (session, tap, etc.). stop() is idempotent and safe to
        // call before isStarted flips to true.
        do {
            try configureSession()
            try await configureEngine()
            try engine.start()
            playerNode.play()
            isStarted = true
        } catch {
            await stop()
            throw error
        }
    }

    /// Idempotent: safe to call regardless of how far start() got. Each step
    /// is guarded by its own `did-start` flag so a partial-start failure
    /// still tears down the audio session and tap.
    ///
    /// The hardware teardown runs off MainActor via Task.detached: AVAudioEngine
    /// stop, removeTap, and AVAudioSession.setActive can each take a noticeable
    /// moment in some scenarios (especially after route changes), and if they
    /// run on MainActor SwiftUI freezes for the duration - which is what was
    /// reproducing as "Stop button hangs the app forever". Yielding MainActor
    /// keeps the UI responsive while the engine cleans up.
    func stop() async {
        guard isStarted || tapInstalled || sessionActivated else { return }

        let needsTap = tapInstalled
        let needsSessionDeactivate = sessionActivated

        isStarted = false
        tapInstalled = false
        sessionActivated = false

        captureContinuation?.finish()
        captureContinuation = nil
        tapInstaller = nil
        bufferQueue.reset()

        let context = AudioTeardownContext(
            engine: engine,
            playerNode: playerNode,
            removeTap: needsTap,
            deactivateSession: needsSessionDeactivate,
            logger: logger
        )

        await Task.detached(priority: .userInitiated) {
            context.perform()
        }.value
    }

    func enqueuePlayback(_ data: Data) {
        guard isStarted else { return }

        // Defense against the AirPods-disconnect-mid-session feedback loop.
        // We block playback ONLY when the active route is the iPhone's loud
        // bottom speaker - that's the route that blasts TTS into the mic and
        // creates a runaway loop. Earpiece (phone-held-to-ear), headphones,
        // AirPods, AirPlay, car audio are all safe and let TTS through.
        guard !Self.isLoudSpeakerOutput else { return }

        guard let buffer = makePlaybackBuffer(from: data) else { return }

        let duration = TimeInterval(buffer.frameLength) / playbackFormat.sampleRate

        let playerNode = self.playerNode
        playerNode.scheduleBuffer(buffer) { [weak bufferQueue, weak playerNode] in
            // Completion handler runs on a non-main audio thread.
            // PlaybackBufferQueue is lock-protected; AVAudioPlayerNode play/pause
            // is safe to call from any thread.
            guard let bufferQueue, let playerNode else { return }
            if bufferQueue.didCompleteBuffer(duration: duration) {
                playerNode.pause()
            }
        }

        let shouldResume = bufferQueue.didQueueBuffer(duration: duration)
        if shouldResume || (!playerNode.isPlaying && bufferQueue.canStartFresh()) {
            playerNode.play()
        }
    }

    // MARK: - Private

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            // Do NOT include .defaultToSpeaker — it overrides A2DP routing and
            // forces output to the iPhone speaker even when AirPods are paired,
            // which causes mic feedback.
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.allowBluetoothA2DP, .duckOthers]
            )
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: [])
            sessionActivated = true
            try session.overrideOutputAudioPort(.none)
        } catch {
            throw LiveTranslationError.audioSessionFailure(error.localizedDescription)
        }
    }

    static var isHeadphonesRouteActive: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { output in
            switch output.portType {
            case .headphones,
                 .bluetoothA2DP,
                 .bluetoothLE,
                 .bluetoothHFP,
                 .airPlay,
                 .usbAudio,
                 .carAudio,
                 .lineOut:
                return true
            default:
                return false
            }
        }
    }

    /// True when the current output route is the iPhone's loud bottom speaker.
    /// This is the only route where playing TTS audio creates a feedback loop
    /// into the mic - the earpiece (held to the ear) is quiet enough that the
    /// mic doesn't pick it up meaningfully, and external routes (headphones,
    /// AirPods, AirPlay, car audio) are all safe by design.
    static var isLoudSpeakerOutput: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { $0.portType == .builtInSpeaker }
    }

    private func configureEngine() async throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw LiveTranslationError.audioEngineFailure("invalid input format")
        }

        // Apply the latest preferred rate every start() in case it was changed
        // while idle. The output graph itself stays attached for the lifetime
        // of this object (set up in init).
        varispeedNode.rate = playbackRate

        guard let continuation = captureContinuation else {
            throw LiveTranslationError.audioEngineFailure("capture stream not initialized")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: captureFormat) else {
            throw LiveTranslationError.audioEngineFailure("converter init failed")
        }

        let installer = TapInstaller(
            converter: converter,
            captureFormat: captureFormat,
            continuation: continuation
        )
        tapInstaller = installer

        // Install the tap from a background queue to ensure the tap closure is
        // not @MainActor-isolated. AVAudioEngine invokes the tap on its realtime
        // audio thread; an inherited MainActor isolation trips
        // _dispatch_assert_queue_fail. Mirrors AudioPrewarmManager's pattern.
        await withCheckedContinuation { resume in
            DispatchQueue.global(qos: .userInitiated).async {
                installLiveTranslationInputTap(
                    inputNode: inputNode,
                    format: inputFormat,
                    installer: installer
                )
                resume.resume()
            }
        }
        tapInstalled = true

        engine.prepare()
    }

    private func makePlaybackBuffer(from data: Data) -> AVAudioPCMBuffer? {
        let int16ByteCount = data.count - (data.count % 2)
        guard int16ByteCount > 0 else { return nil }

        let frameCount = AVAudioFrameCount(int16ByteCount / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        guard let floatChannel = buffer.floatChannelData?[0] else { return nil }

        data.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
            let int16Ptr = rawPtr.bindMemory(to: Int16.self)
            for index in 0..<Int(frameCount) {
                let sample = Int16(littleEndian: int16Ptr[index])
                floatChannel[index] = Float(sample) / 32768.0
            }
        }

        return buffer
    }
}

/// Tracks how much TTS audio is currently scheduled on the player node and
/// gates playback so that we accumulate enough buffer before resuming after
/// starvation. Without this, faster playback rates drain the queue almost as
/// quickly as audio arrives, producing rapid stutter. With a refill threshold
/// we trade rapid micro-gaps for rarer, longer pauses that sound smoother.
nonisolated private final class PlaybackBufferQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var queuedDuration: TimeInterval = 0
    private var isStarved = true
    private var hasEverStarted = false

    /// Buffer that must be queued before playback resumes after the queue
    /// has emptied. Higher values produce fewer, longer gaps. Tuned to ~1s
    /// so a single Russian phrase can usually play continuously.
    private let refillThreshold: TimeInterval = 1.0

    /// Threshold below which the queue is considered empty.
    private let lowWaterMark: TimeInterval = 0.05

    /// Returns `true` if the caller should resume playback.
    nonisolated func didQueueBuffer(duration: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        queuedDuration += duration

        if isStarved && queuedDuration >= refillThreshold {
            isStarved = false
            hasEverStarted = true
            return true
        }
        return false
    }

    /// Returns `true` if the caller should pause playback (queue starved).
    nonisolated func didCompleteBuffer(duration: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        queuedDuration -= duration
        if queuedDuration < 0 { queuedDuration = 0 }

        if !isStarved && queuedDuration <= lowWaterMark {
            isStarved = true
            return true
        }
        return false
    }

    /// Allows kick-starting playback the very first time without crossing the
    /// refill threshold (so the listener doesn't wait too long for first audio).
    nonisolated func canStartFresh() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !hasEverStarted && queuedDuration > 0
    }

    nonisolated func reset() {
        lock.lock()
        defer { lock.unlock() }
        queuedDuration = 0
        isStarved = true
        hasEverStarted = false
    }
}

/// Hardware-side teardown of the AVAudioEngine + AVAudioSession. Wrapped in a
/// `@unchecked Sendable` class so we can run it on a detached Task without
/// MainActor isolation. AVAudioEngine, AVAudioPlayerNode, and AVAudioSession
/// are all documented as thread-safe for these operations - the wrapper just
/// satisfies Swift 6's strict concurrency checking.
///
/// Each step logs entry/exit so the device console pinpoints which call stalls
/// if the hang ever resurfaces. We deliberately do NOT pass
/// `.notifyOthersOnDeactivation` - it triggers synchronous notifications to
/// other apps that have been observed to take seconds in some iOS scenarios.
nonisolated private final class AudioTeardownContext: @unchecked Sendable {
    private let engine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let removeTap: Bool
    private let deactivateSession: Bool
    private let logger: Logger

    nonisolated init(
        engine: AVAudioEngine,
        playerNode: AVAudioPlayerNode,
        removeTap: Bool,
        deactivateSession: Bool,
        logger: Logger
    ) {
        self.engine = engine
        self.playerNode = playerNode
        self.removeTap = removeTap
        self.deactivateSession = deactivateSession
        self.logger = logger
    }

    nonisolated func perform() {
        logger.logInfo("Audio teardown: stopping player node")
        playerNode.stop()

        if removeTap {
            logger.logInfo("Audio teardown: removing input tap")
            engine.inputNode.removeTap(onBus: 0)
        }

        logger.logInfo("Audio teardown: stopping engine")
        engine.stop()

        if deactivateSession {
            logger.logInfo("Audio teardown: deactivating session")
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                logger.logWarning("Audio session deactivate failed: \(error.localizedDescription)")
            }
        }

        logger.logInfo("Audio teardown: complete")
    }
}

/// Installs the AVAudioEngine input tap from a non-isolated context so the
/// resulting closure does not inherit MainActor isolation. The closure is
/// invoked on AVAudioEngine's realtime audio thread.
nonisolated private func installLiveTranslationInputTap(
    inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    installer: TapInstaller
) {
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
        installer.process(buffer)
    }
}

/// Holds state used inside the realtime audio tap callback. Runs entirely on the
/// AVAudioEngine input thread - never touches MainActor state. The continuation
/// is the only cross-thread channel and `AsyncStream.Continuation` is Sendable.
nonisolated private final class TapInstaller: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let captureFormat: AVAudioFormat
    private let continuation: AsyncStream<Data>.Continuation

    nonisolated init(converter: AVAudioConverter, captureFormat: AVAudioFormat, continuation: AsyncStream<Data>.Continuation) {
        self.converter = converter
        self.captureFormat = captureFormat
        self.continuation = continuation
    }

    nonisolated func process(_ buffer: AVAudioPCMBuffer) {
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

        guard outBuffer.frameLength > 0,
              let channelData = outBuffer.int16ChannelData else {
            return
        }

        let byteCount = Int(outBuffer.frameLength) * 2
        let data = Data(bytes: channelData[0], count: byteCount)
        continuation.yield(data)
    }
}
