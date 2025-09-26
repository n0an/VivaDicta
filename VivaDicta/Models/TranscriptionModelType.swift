//
//  TranscriptionModelType.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import Foundation

enum TranscriptionModelType: String, CaseIterable, Identifiable {
    var id: Self { self }
    case local
    case cloud
}