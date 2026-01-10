//
//  AudioPlayerView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.07
//

import SwiftUI
import AVFoundation
import os

struct WaveformGenerator {
    
    static func generateWaveformSamples(from url: URL, sampleCount: Int = 100) async -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return []
        }
        
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        let stride = max(1, Int(frameCount) / sampleCount)
        let bufferSize = min(UInt32(4096), frameCount)
                
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else { 
            return []
        }
        
        do {
            var maxValues = [Float](repeating: 0.0, count: sampleCount)
            var sampleIndex = 0
            var framePosition: AVAudioFramePosition = 0
            
            while sampleIndex < sampleCount && framePosition < AVAudioFramePosition(frameCount) {
                audioFile.framePosition = framePosition
                try audioFile.read(into: buffer)
                
                if let channelData = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                    maxValues[sampleIndex] = abs(channelData[0])
                    sampleIndex += 1
                }
                
                framePosition += AVAudioFramePosition(stride)
            }
            
            if let maxSample = maxValues.max(), maxSample > 0 {
                let normalizedValues = maxValues.map { $0 / maxSample }
                return normalizedValues
            }
            return maxValues
        } catch {
            return []
        }
    }
}

@Observable
class AudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    private let logger = Logger(category: .audioPlayerManager)
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var waveformSamples: [Float] = []
    var isLoadingWaveform = false
    
    func loadAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            isLoadingWaveform = true
            
            Task {
                let samples = await WaveformGenerator.generateWaveformSamples(from: url)
                await MainActor.run {
                    self.waveformSamples = samples
                    self.isLoadingWaveform = false
                }
            }
        } catch {
            logger.logError("❌ Error loading audio: \(error.localizedDescription)")
        }
    }
    
    func play() {
        configureAudioSession()
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    private func configureAudioSession() {
        // Don't change session if prewarm recording is active
        if AudioPrewarmManager.shared.isSessionActive {
            logger.logDebug("Skipping audio session configuration - prewarm session active")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            logger.logError("❌ Error configuring audio session: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = self.audioPlayer?.currentTime ?? 0
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        seek(to: 0)
    }
}

struct WaveformView: View {
    let samples: [Float]
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isLoading: Bool
    var onSeek: (Double) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 1) {
                        ForEach(0..<samples.count, id: \.self) { index in
                            WaveformBar(
                                sample: samples[index],
                                isPlayed: CGFloat(index) / CGFloat(samples.count) <= CGFloat(currentTime / duration),
                                totalBars: samples.count,
                                geometryWidth: geometry.size.width
                            )
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .contentShape(.rect)
            .onTapGesture { location in
                if !isLoading {
                    HapticManager.selectionChanged()
                    let progress = location.x / geometry.size.width
                    onSeek(Double(progress) * duration)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isLoading {
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek(Double(progress) * duration)
                        }
                    }
            )
        }
        .frame(height: 40)
    }
}

struct WaveformBar: View {
    let sample: Float
    let isPlayed: Bool
    let totalBars: Int
    let geometryWidth: CGFloat
    
    var body: some View {
        Capsule()
            .fill(isPlayed ? Color.blue : Color.blue.opacity(0.3))
            .frame(
                width: max((geometryWidth / CGFloat(totalBars)) - 1, 1),
                height: max(CGFloat(sample) * 32, 3)
            )
    }
}

struct AudioPlayerView: View {
    let audioFileName: String
    @State private var playerManager = AudioPlayerManager()
    
    private var audioURL: URL? {
        FileManager.appDirectory(for: .audio).appendingPathComponent(audioFileName)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayback) {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.blue)
                    )
            }
            .disabled(audioURL == nil)
            
            WaveformView(
                samples: playerManager.waveformSamples,
                currentTime: playerManager.currentTime,
                duration: playerManager.duration,
                isLoading: playerManager.isLoadingWaveform,
                onSeek: { playerManager.seek(to: $0) }
            )
        }
        .onAppear {
            if let url = audioURL {
                playerManager.loadAudio(from: url)
            }
        }
        .onDisappear {
            playerManager.pause()
        }
    }
    
    private func togglePlayback() {
        HapticManager.playbackToggled()
        if playerManager.isPlaying {
            playerManager.pause()
        } else {
            playerManager.play()
        }
    }
}
