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
        
        List {
            ForEach(transcriptions) { transcription in
                
                Text(transcription.text)
                
            }
        }
        
        
    }
}

#Preview(traits: .transcriptionsMockData) {
    TranscriptionsView()
}
