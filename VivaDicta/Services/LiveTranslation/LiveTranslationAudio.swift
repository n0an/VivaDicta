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

    /// Playback rate for the TTS audio. Russian/translated text often runs
    /// longer than the source speech; speeding up modestly keeps the queue
    /// from growing during long sessions without sounding chipmunked.
    static let playbackRate: Float = 1.15

    private let logger = Logger(category: .liveTranslationAudio)
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let varispeedNode = AVAudioUnitVarispeed()

    private var captureContinuation: AsyncStream<Data>.Continuation?
    private var isStarted = false
    private var tapInstaller: TapInstaller?

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

    func makeCaptureStream() -> AsyncStream<Data> {
        AsyncStream<Data> { continuation in
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

        try configureSession()
        try await configureEngine()
        try engine.start()
        playerNode.play()
        isStarted = true
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        playerNode.stop()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        captureContinuation?.finish()
        captureContinuation = nil
        tapInstaller = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            logger.logWarning("Audio session deactivate failed: \(error.localizedDescription)")
        }
    }

    func enqueuePlayback(_ data: Data) {
        guard isStarted else { return }
        guard let buffer = makePlaybackBuffer(from: data) else { return }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        // After long silences the engine may suspend the player node implicitly.
        // Re-arm it whenever new audio arrives.
        if !playerNode.isPlaying {
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

    private func configureEngine() async throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw LiveTranslationError.audioEngineFailure("invalid input format")
        }

        engine.attach(playerNode)
        engine.attach(varispeedNode)
        varispeedNode.rate = Self.playbackRate
        engine.connect(playerNode, to: varispeedNode, format: playbackFormat)
        engine.connect(varispeedNode, to: engine.mainMixerNode, format: playbackFormat)

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
