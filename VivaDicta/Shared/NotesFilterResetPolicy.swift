//
//  NotesFilterResetPolicy.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import Foundation

enum NotesFilterResetPolicy {
    static func shouldResetToAllAfterDeletion(
        hasActiveFilter: Bool,
        isSearching: Bool,
        oldTranscriptionCount: Int,
        newTranscriptionCount: Int,
        remainingFilteredCount: Int
    ) -> Bool {
        guard hasActiveFilter else { return false }
        guard !isSearching else { return false }
        guard newTranscriptionCount < oldTranscriptionCount else { return false }
        guard newTranscriptionCount > 0 else { return false }
        return remainingFilteredCount == 0
    }
}
