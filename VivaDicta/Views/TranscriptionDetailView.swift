//
//  TranscriptionDetailView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.07
//

import SwiftUI

struct TranscriptionDetailView: View {
    
    var transcription: Transcription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AudioPlayerView(audioFileName: transcription.audioFileName)
                .padding(.bottom, 8)
            
            HStack {
                Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                Spacer()
                
                Text(transcription.audioDurationFormatted)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            
            Text(transcription.text)
                .font(.system(size: 15, weight: .regular, design: .default))
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    TranscriptionDetailView(transcription: Transcription.mockData[2])
}
