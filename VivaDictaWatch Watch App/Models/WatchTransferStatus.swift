//
//  WatchTransferStatus.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import Foundation

enum WatchTransferStatus: Equatable {
    case idle
    case transferring(count: Int)
    case allUploaded
    case error(String)
}
