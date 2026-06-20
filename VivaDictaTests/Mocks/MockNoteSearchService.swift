// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
@testable import VivaDicta

/// Capturing mock of ``NoteSearchService``. Stubs the search result and records
/// the queries it was asked, so tests can drive ``SmartSearchChatViewModel``
/// without standing up the real RAG vector index (``RAGIndexingService.shared``).
@MainActor
final class MockNoteSearchService: NoteSearchService {
    var stubResult: Result<[RAGSearchResult], Error> = .success([])
    private(set) var capturedQueries: [(query: String, topK: Int)] = []
    var searchCallCount: Int { capturedQueries.count }

    func search(query: String, topK: Int) async throws -> [RAGSearchResult] {
        capturedQueries.append((query, topK))
        return try stubResult.get()
    }
}
