// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

extension Collection where Element == Transcription {
    /// The notes keyed by `id`, tolerating duplicate ids.
    ///
    /// `Dictionary(uniqueKeysWithValues:)` traps on a repeated key, and a
    /// repeated key is reachable here: models synced through CloudKit cannot
    /// carry `@Attribute(.unique)`, so nothing at the storage layer stops two
    /// rows from sharing an `id`. A sync merge or a restore is enough to
    /// produce one, and the notes list then crashed on the next search rather
    /// than showing the duplicate.
    ///
    /// First one wins. The two rows are the same note as far as a lookup by id
    /// is concerned, so which survives does not matter - not crashing does.
    var indexedByID: [UUID: Transcription] {
        Dictionary(map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
