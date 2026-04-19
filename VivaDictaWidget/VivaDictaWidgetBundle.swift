//
//  VivaDictaWidgetBundle.swift
//  VivaDictaWidget
//
//  Created by Anton Novoselov on 2025.10.02
//

import WidgetKit
import SwiftUI

@main
struct VivaDictaWidgetBundle: WidgetBundle {
    var body: some Widget {
        VivaDictaIconWidget()
        VivaDictaAskRecordWidget()
        VivaDictaWidgetControl()
        VivaDictaLiveActivity()
    }
}
