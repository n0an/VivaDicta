//
//  RecordView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI

struct RecordView: View {
    @State var viewModel = RecordViewModel()
    
    var body: some View {
        VStack {
            Button {
                viewModel.recordButtonTapped()
            } label: {
                Label(viewModel.recordButtonParams.0, systemImage: viewModel.recordButtonParams.1)
            }
        }
    }
}

#Preview {
    RecordView()
}
