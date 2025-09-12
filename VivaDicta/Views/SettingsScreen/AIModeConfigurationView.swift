//
//  AIModeConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct AIModeConfigurationView: View {
    
    var mode: AIEnhanceModeType
    
    var body: some View {
        Text(mode.name)
    }
}
