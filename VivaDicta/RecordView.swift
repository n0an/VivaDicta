//
//  RecordView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI

struct RecordView: View {
    @State var viewModel: RecordViewModel
    
    init() {
        self._viewModel = State(wrappedValue: RecordViewModel())
    }
    
    var body: some View {
        VStack {
            Button(viewModel.isRecording ? "Stop" : "Record") {
                viewModel.isRecording.toggle()
            }
        }
    }
}

#Preview {
    RecordView()
}
