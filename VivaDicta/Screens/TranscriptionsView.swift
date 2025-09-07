//
//  TranscriptionsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.11
//

import SwiftUI
import SwiftData

struct TranscriptionsView: View {
    @Query(sort: \Transcription.timestamp, order: .reverse) private var transcriptions: [Transcription]
    
    var body: some View {
        
        NavigationStack {
            List {
                ForEach(transcriptions) { transcription in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            Text(formatTiming(transcription.audioDuration))
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        
                        Text(transcription.text)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .lineLimit(2)
                            .lineSpacing(2)
                    }
                    
                }
            }
            .listStyle(.plain)
            .navigationTitle("Transcriptions")
        }
    }
    
    private func formatTiming(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return (duration * 1000).formatted(.number.precision(.fractionLength(0))) + "ms"
        }
        if duration < 60 {
            return duration.formatted(.number.precision(.fractionLength(1))) + "s"
        }
        return Duration.seconds(round(duration))
            .formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }
    
}

#Preview(traits: .transcriptionsMockData) {
    TranscriptionsView()
}
