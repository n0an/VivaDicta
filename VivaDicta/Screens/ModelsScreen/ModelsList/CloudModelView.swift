//
//  CloudModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.15
//

import SwiftUI

struct CloudModelView: View {
    private var model: CloudTranscriptionModel
    private var onSelect: (CloudTranscriptionModel) -> Void
    
    var body: some View {
        HStack {
            Text("\(model.rawValue)")
            Spacer()
            selectButton
        }
        .padding()
    }
    
    var selectButton: some View {
        Button("Select") {
            onSelect(model)
        }
        .foregroundStyle(.white)
        .padding(8)
        .background(.green, in: .rect(cornerRadius: 8))
    }
    
    init(model: CloudTranscriptionModel,
         onSelect: @escaping (CloudTranscriptionModel) -> Void) {
        self.model = model
        self.onSelect = onSelect
    }
}

#Preview {
    CloudModelView(model: .openAI) {  _ in }
}
