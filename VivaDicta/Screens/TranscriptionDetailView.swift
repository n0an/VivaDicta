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
        Text(transcription.text)
    }
}

#Preview {
    TranscriptionDetailView(transcription: Transcription.mockData[2])
}
