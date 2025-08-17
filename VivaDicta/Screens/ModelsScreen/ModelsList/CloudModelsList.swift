//
//  CloudModelsList.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.15
//

import SwiftUI

struct CloudModelsList: View {
    var body: some View {
        List {
            Section(header: Text("Cloud Models")) {
                ForEach(CloudTranscriptionModel.allCases) { model in
                    CloudModelView(model: model) { model in
                        loadModel(cloudModel: model)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }
    
    func loadModel(cloudModel: CloudTranscriptionModel) {
        
    }
}

#Preview {
    CloudModelsList()
}
