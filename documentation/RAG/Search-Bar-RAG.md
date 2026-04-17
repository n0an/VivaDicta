# Main Search Bar RAG

## Overview

The notes list (`TranscriptionsContentView`) has a search bar that combines SwiftData keyword search with RAG-based semantic search.

Three user-facing modes, exposed via a segmented `Picker` when the search text is non-empty:

- **All** - keyword results + smart matches in parallel sections
- **Keyword** - SwiftData predicate only
- **Smart** - semantic search via the same `RAGIndexingService` used by Smart Chat

Smart modes are only available when `SmartSearchFeature.isEnabled` is true. When disabled, the picker is hidden and only keyword search runs.

## State

```swift
@AppStorage(SmartSearchFeature.isEnabledKey) isSmartSearchEnabled
@Query allTranscriptions
@State filteredTranscriptions: [Transcription]     // keyword results
@State smartSearchMatches: [SemanticSearchMatch]   // RAG results
@State semanticScoresByID: [UUID: Float]           // for "Smart" score pills
@State searchMode: TranscriptionSearchMode = .all  // .all | .keyword | .smart
@State searchTask: Task<Void, Never>?              // debouncer
```

`searchMode` resets to `.keyword` automatically when Smart Search gets disabled.

## Trigger

On `searchText` change, `performDebouncedSearch(with:)` cancels any in-flight task and starts a new one.

Debounce: 200 ms sleep. Empty search clears everything and exits.

## Branching

After debounce, the task picks a path:

1. Empty term -> clear results
2. `!isSmartSearchEnabled` -> keyword only
3. `searchMode == .keyword` -> keyword only
4. `!shouldRunSemanticSearch(for:)` -> keyword only
5. Otherwise -> keyword results + RAG, combined per mode

### Keyword Path

`keywordSearchResults(for:)`:

- SwiftData `FetchDescriptor<Transcription>` with predicate matching `text` OR `enhancedText` via `localizedStandardContains`
- Separate `FetchDescriptor<TranscriptionVariation>` with predicate matching `text`
- Transcription ids from variation matches are unioned into the result set
- Final array sorted by `timestamp` descending

Keyword mode searches across the three text surfaces a user might remember:

- raw transcription text
- latest AI-enhanced text cache
- any saved variation output

### RAG Gate

`shouldRunSemanticSearch(for searchTerm: String) -> Bool` blocks very short inputs to avoid wasting embedding computation and getting noisy hits:

- trimmed length must be `>= 4`
- split on non-letter/non-number boundaries into tokens
- pass if any token is `>= 4` chars
- otherwise pass if there are `>= 2` tokens with combined letter/number length `>= 6`

Examples: `"lua"` fails, `"dict"` passes (single 4-char token), `"go ai"` passes (2 tokens, total 4 chars... actually fails by that rule - requires combined >= 6).

### Semantic Path

`semanticSearchMatches(for searchTerm:)`:

1. Calls `RAGIndexingService.shared.search(query: searchTerm, topK: 20)`
2. Maps `RAGSearchResult` -> `SemanticSearchMatch { transcriptionId, relevanceScore }`
3. Returns top 20 candidates (not filtered further by the view)

Notice: `topK = 20` here vs 3-5 in Smart Chat. The search bar wants a longer list because the user can scroll.

The underlying retrieval rules match the rest of the RAG stack:

- threshold `0.25`
- over-fetch `topK * 2 = 40` raw chunk hits
- keep best chunk per transcription id
- return up to 20 transcription matches

## Mode Results Assembly

After the task resolves, the view picks what to show:

### `.all` (default when Smart Search is enabled)

Both lists populate independently:

- `keywordDisplayedTranscriptions` - keyword results filtered by active tag filters
- `smartDisplayedTranscriptions` - smart matches filtered by active tag filters

Rendered as two sections in `TranscriptionsListView`:

- `Section("Keyword Matches")`
- `Section("Smart Matches")`

`displayedTranscriptionIDs` (used for selection-mode operations) is the union of both lists.

### `.keyword`

Only `keywordDisplayedTranscriptions` shown. No semantic scores.

### `.smart`

Only `smartDisplayedTranscriptions`, ordered by the RAG score order returned. The `semanticScoresByID` dictionary drives relevance pills on each row via `currentSemanticScore(for:)`.

If the filtered smart list is empty, a ContentUnavailable "No Smart Matches" view is shown suggesting different wording or a switch to Keyword.

## Tag Filtering

Tag filters (source tag + user-defined tags) apply **after** retrieval, not as part of the RAG or SwiftData predicate:

- `matchesActiveTags(for:)` checks source tag intersection AND user tag intersection
- Applied to both keyword and smart lists independently

This keeps retrieval cheap and lets the user narrow results by tag without re-running the whole search.

## Query Preparation

There is no planner here. The raw user query is handed directly to `RAGIndexingService.shared.search(...)`. The search bar assumes the user already typed what they want to match.

That is the main difference from chat surfaces - chat surfaces always run a planner first to strip framing like "did I mention" and "similar" from conversational queries.

## What Gets Injected

Nothing. The search bar is a retrieval UI, not an LLM surface. It returns `Transcription` rows for display and does not construct any prompt.

## Score Pills

In `.smart` mode, each row can display a relevance pill. `currentSemanticScore(for transcriptionID:)` returns the score only when `isSmartSearchEnabled && searchMode == .smart`. In `.all` mode the same value is available via `semanticScoreProvider` but only rendered in the Smart Matches section.

## Deletion

`deleteSmartTranscriptions(at:)` handles the Smart section swipe-delete:

- For each deleted transcription: `modelContext.delete(...)` then `RAGIndexingService.shared.removeTranscription(id:)`
- The RAG removal deletes the chunks from the vector store and clears the id mapping

## Discovery Tip

`SmartSearchDiscoveryTip` (TipKit) surfaces above the list when there are no search results and Smart Search is enabled, nudging the user to switch modes. Donating `smartSearchPerformedEvent` dismisses the tip.

## Logging

Look for these in Console (category `transcriptionsContentView` and `ragSearch`):

- `Semantic notes search start query='...' indexedNotes=N`
- `Semantic notes search finished query='...' matchedNotes=N`
- `RAG search start query='...' topK=20 requested=40 threshold=0.25 mappedNotes=N indexedNotes=N indexingCompleted=true`
- `Search 'xxx': N transcriptions matched`

## Failure Cases

| Case | Behavior |
|---|---|
| Search text empty | both lists cleared |
| Smart Search disabled | keyword only, picker hidden |
| Term too short (`shouldRunSemanticSearch == false`) | keyword only, smart list empty |
| RAG search throws | logged error, smart list empty, keyword still shown |
| Index empty (`mappedNotes = 0`) | diagnostic log, smart list empty |
| User switches off Smart Search | `searchMode = .keyword`, semantic scores cleared |

## Key Files

- [VivaDicta/Views/TranscriptionsContentView.swift](../../VivaDicta/Views/TranscriptionsContentView.swift)
- [VivaDicta/Services/RAG/RAGIndexingService.swift](../../VivaDicta/Services/RAG/RAGIndexingService.swift)
- [VivaDicta/Views/Tips/SmartSearchDiscoveryTip.swift](../../VivaDicta/Views/Tips/SmartSearchDiscoveryTip.swift)
