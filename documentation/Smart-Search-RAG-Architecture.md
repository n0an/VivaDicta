# Smart Search RAG Architecture

## Overview

Smart Search is VivaDicta's retrieval-augmented chat mode for searching across the user's transcription notes.

The same local RAG index also powers the Smart mode in the main notes search surface.

Unlike single-note chat and multi-note chat, Smart Search does not start with a fixed note set. For every user turn, it:

1. Semantically searches the local note index.
2. Maps chunk hits back to source notes.
3. Injects the retrieved chunk excerpts into the prompt when evidence exists.
4. Falls back to sending the raw user question when retrieval returns no note hits.
5. Persists note-level and excerpt-level citations on the assistant message.

The current setup is:

- Chunking and indexing via `LumoKit`
- Vector search via `VecturaKit`
- Embeddings via `SwiftEmbedder`
- Current embedding model: `minishlab/potion-base-32M`
- Current chunking: semantic, `chunkSize = 500`, `overlap = 15%`
- Current retrieval: always search, then inject the ranked chunk hits when available
- Current empty-retrieval behavior in chat: send the raw question to the model
- Current prompt injection: chunk excerpts, not full notes
- Feature flag: Smart Search can be disabled from Settings, which clears the local index and hides Smart Search surfaces

Smart Search intentionally does not use a pre-retrieval router. The local corpus is small enough that always searching is acceptable, and the reliability work happens after retrieval, not before it.

## Why This Architecture Exists

The core problem Smart Search is trying to solve is:

- let the user ask open-ended questions about all notes
- keep the answer grounded in real note content
- avoid stuffing entire notes into every prompt
- keep citations understandable and tappable

This leads to several deliberate design choices:

- Index raw note text, not `enhancedText`
- Retrieve chunks, not entire notes
- Inject chunk excerpts into the LLM prompt
- Keep note-level references in the UI
- Keep the retrieval path simple and always-on

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         Smart Search Surfaces                             │
│                                                                            │
│  SmartSearchChatView                  TranscriptionsContentView            │
│  ┌──────────────────────────────┐    ┌──────────────────────────────────┐ │
│  │ Chat bubbles                 │    │ All | Keyword | Smart           │ │
│  │ Source pills                 │    │ Smart semantic result rows      │ │
│  │ Full answer generation       │    │ Match score badges              │ │
│  └──────────────────────┬───────┘    └───────────────────┬──────────────┘ │
└─────────────────────────────────│──────────────────────────────────────────┘
                                  │
                                  ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                        SmartSearchChatViewModel                            │
│                                                                            │
│  sendMessage()                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 1. semantic search via RAGIndexingService                           │  │
│  │ 2. pass raw user query through when retrieval is empty              │  │
│  │ 3. resolve source Transcription models                              │  │
│  │ 4. assemble augmented prompt with chunk excerpts                    │  │
│  │ 5. send to provider via AIService / Apple FM                        │  │
│  │ 6. persist assistant message + citations                            │  │
│  └──────────────────────────────┬───────────────────────────────────────┘  │
└─────────────────────────────────│──────────────────────────────────────────┘
                                  │
                                  ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                           RAGIndexingService                              │
│                                                                            │
│  LumoKit(config, chunkingConfig, modelSource)                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ SwiftEmbedder(modelSource: "minishlab/potion-base-32M")            │  │
│  │ semantic chunking                                                   │  │
│  │ local vector store                                                  │  │
│  │ chunk-id -> transcription-id mapping in UserDefaults                │  │
│  └──────────────────────────────┬───────────────────────────────────────┘  │
└─────────────────────────────────│──────────────────────────────────────────┘
                                  │
                                  ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                          Local Vector Database                             │
│                                                                            │
│  One note -> many chunks -> many vectors                                   │
│  Search returns chunk hits                                                  │
│  App maps them back to note IDs                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

## Main Components

### `RAGIndexingService`

File: [VivaDicta/Services/RAG/RAGIndexingService.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/RAG/RAGIndexingService.swift)

Responsibilities:

- initialize `LumoKit`
- define vector DB namespace and search options
- chunk and index transcription text
- keep persistent `transcriptionId -> [chunkId]` mapping
- keep persistent stable content hashes for incremental reindexing
- perform semantic search and map raw chunk hits back to notes
- expose observable indexing state for Smart Search settings and chat UI

### `SmartSearchChatViewModel`

File: [VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift)

Responsibilities:

- execute retrieval for each user message
- pass the raw user message through when retrieval returns no note hits
- resolve note models for retrieved hits
- assemble source citations
- build the augmented prompt
- send the final request through `AIService` or Apple Foundation Models

### `SmartSearchContextManager`

File: [VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift)

Responsibilities:

- define Smart Search system prompt
- wrap retrieved excerpts in plain-text `SOURCE` sections
- format the augmented prompt for cloud and Apple FM chat paths

### `TranscriptionsContentView`

File: [VivaDicta/Views/TranscriptionsContentView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionsContentView.swift)

Responsibilities in Smart Search mode:

- run keyword-only search in `Keyword`
- run keyword plus semantic search in `All`
- run semantic search only in `Smart`
- show semantic match scores on Smart result rows
- avoid running semantic search at all when the user explicitly selected `Keyword`

### `ChatMessage` citation storage

File: [VivaDicta/Models/ChatMessage.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Models/ChatMessage.swift)

Smart Search assistant messages persist:

- `sourceTranscriptionIds`
- `sourceCitations`

Each `SmartSearchSourceCitation` stores:

- `transcriptionId`
- `excerpt`
- `relevanceScore`

This lets the UI show evidence-oriented citation pills instead of only note titles.

## Embedding and Chunking Configuration

Current embedder setup in `RAGIndexingService`:

```swift
let kit = try await LumoKit(
    config: config,
    chunkingConfig: chunkingConfig,
    modelSource: .id("minishlab/potion-base-32M")
)
```

Current vector DB configuration:

- vector store name: derived from `indexVersion`
- current namespace: `v14_potion_base_32m`
- Vectura config default results: `5`
- Vectura config default threshold: `0.35`
- runtime Smart Search query threshold: `0.4`

Current chunking configuration:

```swift
ChunkingConfig(
    chunkSize: 500,
    overlapPercentage: 0.15,
    strategy: .semantic,
    contentType: .prose
)
```

Meaning in practice:

- Smart Search uses semantic chunking, not naive fixed paragraph splitting
- notes are split into overlapping chunks
- chunk overlap helps avoid losing context at boundaries
- the app stores one vector record per chunk, not one vector record per note

## Why Raw Note Text Is Indexed

Smart Search indexes:

- `transcription.text`

It intentionally does **not** index:

- `transcription.enhancedText`
- `TranscriptionVariation` records

Reason:

- `enhancedText` may be a short summary or stylistic rewrite
- summaries collapse nuance and remove terms that matter for retrieval
- Smart Search needs the richest available source text

This is handled by `indexableContent(for:)` in `RAGIndexingService`.

## Indexing Flow

### Startup indexing

Indexing is kicked off on app launch in [VivaDicta/VivaDictaApp.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/VivaDictaApp.swift).

If Smart Search is enabled, callers that hit the service during startup now await the shared initialization task instead of surfacing a transient initialization error.

```
┌──────────────────────────────────────────────────────────────────────────┐
│ App launch                                                              │
└──────────────────────────────┬───────────────────────────────────────────┘
                               ▼
                 RAGIndexingService.indexAllIfNeeded()
                               │
                               ▼
            Fetch all Transcription records from SwiftData
                               │
                               ▼
               For each note: transcription.text -> stable hash
                               │
             ┌─────────────────┴──────────────────┐
             │                                    │
             ▼                                    ▼
     hash unchanged                        hash changed / first run
             │                                    │
             ▼                                    ▼
          skip                         remove old chunks for note
                                                  │
                                                  ▼
                                     semantic chunking via LumoKit
                                                  │
                                                  ▼
                                      add chunk texts to vector DB
                                                  │
                                                  ▼
                                store chunk IDs in UserDefaults mapping
```

### Incremental updates

Smart Search reindexes individual notes when note content changes.

Important call sites include:

- [VivaDicta/Views/RecordViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/RecordViewModel.swift)
- [VivaDicta/Views/TranscriptionDetailView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionDetailView.swift)
- [VivaDicta/Views/MainView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/MainView.swift)

That means:

- new notes get indexed
- edited notes get re-chunked and re-indexed
- deleted notes have their chunks removed

### Stable hashes

The service stores deterministic SHA-256 hashes of indexed note text.

This avoids using Swift's non-stable `hashValue`, and makes incremental indexing reliable across launches and devices.

## Retrieval Flow

Smart Search chat currently performs retrieval for every message and uses the ranked results directly.

```
┌──────────────────────────────────────────────────────────────────────────┐
│ User sends message                                                      │
└──────────────────────────────┬───────────────────────────────────────────┘
                               ▼
                SmartSearchChatViewModel.sendMessage()
                               │
                               ▼
               semantic search in RAGIndexingService
                               │
                               ▼
                     raw chunk hits from vector DB
                               │
                               ▼
                 map chunk IDs back to transcription IDs
                               │
                               ▼
                  keep best-ranked chunk per note
                               │
             ┌─────────────────┴──────────────────┐
             │                                    │
             ▼                                    ▼
        no note hits                      note hits exist
             │                                    │
             ▼                                    ▼
      raw query sent to model           prompt includes SOURCE excerpts
                                                  │
                                                  ▼
                                         provider generates answer
                                                  │
                                                  ▼
                                   store citations on assistant message
```

### Search details

`RAGIndexingService.search(...)` currently does the following:

- uses threshold `0.4`
- over-fetches `topK * 2` chunk hits
- maps raw chunk hits back to notes using persisted chunk mapping
- optionally computes shared lexical query terms using `SmartSearchLexicalSupport`
- deduplicates by note, keeping the best-ranked chunk per note
- with lexical reranking disabled, keeps the best note chunk by returned semantic score only
- with lexical reranking enabled, prefers lexical overlap first, then semantic score

Current top-k callers:

- Smart Search chat requests `3` results for Apple Foundation Models
- Smart Search chat requests `5` results for cloud providers
- the main search bar Smart mode requests `20` note hits so it can show a broader result list

This means Smart Search is currently a:

- chunk-level retrieval system
- note-level deduplication system
- excerpt-level prompt injection system

## Search Bar Smart Mode

The main search surface shares the same `RAGIndexingService.search(...)` backend, but uses it differently from Smart Search chat.

Current search modes:

- `Keyword` - keyword search only, no semantic retrieval
- `All` - keyword results first, Smart semantic results below
- `Smart` - semantic results only

Important differences from Smart Search chat:

- search bar does not inject chunk text into any prompt
- search bar uses chunk hits only to rank and select notes
- search bar shows note rows with semantic score badges, not excerpt pills
- clearing the query resets the mode away from hidden Smart-only state

So both surfaces share the same chunk-level retrieval engine, but only Smart Search chat turns retrieved chunks into model context.

## Chunk Injection

Today Smart Search injects:

- only the matched chunk excerpt for each retrieved hit

It does **not** inject:

- the full deduplicated note body

Prompt assembly looks like:

```text
SOURCE 1
Title: First line of the note
Date: Apr 12, 2026 at 8:42 PM
Excerpt:
[matched chunk excerpt]
```

This happens in `SmartSearchContextManager.assembleAugmentedPrompt(...)`.

Benefits:

- less prompt noise
- lower token usage
- tighter prompt focus around the retrieved evidence
- clearer citation UX

Current limitation:

- there is no `-1 / hit / +1` chunk window yet
- only the single best chunk per note is injected

## Deterministic Safeguards

Smart Search contains one deterministic shortcut in code, but it is currently inactive in normal use.

### 1. No-evidence response

The code path returns a fixed response only if:

- the query is not empty after trimming
- retrieval ran
- retrieval returned no note hits
- `groundedQueryTerms(from:)` returned at least one substantive term

That last condition currently depends on `SmartSearchLexicalSupport.queryTerms(from:)`.
Because lexical reranking is disabled right now, `queryTerms(from:)` returns an empty set, so the no-evidence shortcut does not currently fire.

In today's behavior, an empty retrieval usually falls through to normal model generation with the raw user question.

Examples:

- English: `I could not find a reliable mention of that in your notes.`
- Russian: `Я не нашел надежного упоминания этого в ваших заметках.`

Purpose:

- prevent the model from answering from world knowledge when there is no trustworthy note evidence
- prevent follow-up hallucinations caused by an unsupported earlier answer

## Shared Lexical Normalization

`SmartSearchLexicalSupport` provides the optional shared lexical normalization used by the app-side reranker and by the current no-evidence gate.

### What it does

When enabled, the lexical support layer:

- lowercases tokens
- strips punctuation into alphanumeric tokens
- applies diacritic-insensitive folding
- adds a simple singular form for some English plural tokens ending in `s`

Purpose:

- provide a lightweight overlap signal on top of Vectura's built-in hybrid retrieval
- help exact-term ranking only if real retrieval evals show Vectura's native ranking is not enough

This behavior is behind a shared code-level flag:

- `SmartSearchLexicalSupport.isLexicalRerankingEnabled`

When the flag is `false`, Smart Search:

- uses Vectura's returned score without app-side lexical overlap preferences
- returns no lexical query terms from `queryTerms(from:)`
- therefore leaves the current no-evidence shortcut inactive

## Why Smart Search Does Not Use a Router

Smart Search does not use a general pre-retrieval router.

The strategy is:

- always retrieve
- use the ranked RAG hits directly
- send the raw query through when retrieval returns no note hits

This applies to Smart Search chat. In the main search bar, `Keyword` mode explicitly skips semantic retrieval.

## Citation and Source UX

After the assistant response is generated, Smart Search stores both:

- note-level IDs
- excerpt-level citation metadata

The UI in [VivaDicta/Views/SmartSearch/SmartSearchChatView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatView.swift):

- shows citation pills below assistant messages
- uses the note date plus the matched excerpt preview
- opens the full note when the user taps a pill

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Assistant message                                                       │
│ "You mentioned castling in a note about building a 3D chess game..."    │
│                                                                          │
│  [Apr 12, 2026 - ...build and test a 3D chess game...]                  │
└──────────────────────────────────────────────────────────────────────────┘
```

This is important because Smart Search is chunk-based internally, but the user still needs a note-level destination they can open and inspect.

## Current Model Choice

The current embedder choice is:

- `SwiftEmbedder` with `minishlab/potion-base-32M`

Why this is the current choice:

- performed better than the multilingual experiments tested so far on the current note corpus
- preserved good English retrieval for queries like `chess`
- stayed compatible with the current upstream `LumoKit` integration

Other models were tested during development, including:

- `minishlab/potion-base-4M`
- `minishlab/potion-retrieval-32M`
- `minishlab/potion-multilingual-128M`
- `intfloat/multilingual-e5-small`
- `sentence-transformers/paraphrase-multilingual-mpnet-base-v2`
- `NLContextualEmbedder(language: .english)`
- MLX experiments such as `multilingual_e5_small` and `bge_m3`

Those experiments informed the current choice. The current implementation uses the simpler and more stable `potion-base-32M` path.

## Current Strengths

- fully local note retrieval
- excerpt injection instead of full-note stuffing
- deterministic incremental indexing
- note-aware citations with excerpt previews
- simple always-retrieve flow with minimal app-side heuristics
- shared local retrieval backend across Smart Search chat and the search bar
- feature flag can fully disable Smart Search and clear the local index

## Current Limitations

- retrieval still always runs for every user message
- runtime search threshold is currently `0.4`
- deduplication keeps only one best chunk per note
- there is no local context window around the matched chunk
- the optional app-side lexical reranker is currently disabled, so all ranking relies on Vectura's native hybrid search
- the current no-evidence shortcut is effectively disabled because substantive-term detection depends on the disabled lexical layer

## Likely Next Improvements

The most likely next improvements are in retrieval logic, not embedder swaps:

1. Improve per-note chunk selection
   - let the best grounded chunk win inside a note
   - or keep multiple chunks per note before final prompt assembly

2. Add optional local chunk window
   - previous / current / next chunk
   - only if chunk-only context proves too narrow

3. Decouple no-evidence fallback from lexical reranking
   - allow a deterministic "not found in notes" response without re-enabling app-side lexical overlap logic

4. Tune citation suppression further
   - avoid showing weak evidence when the final answer is effectively "not found"

4. Add a repeatable evaluation set
   - fixed test questions with expected note IDs
   - compare retrieval changes without relying only on manual memory

## Files to Read First

If you need to understand or change Smart Search RAG, start here:

1. [VivaDicta/Services/RAG/RAGIndexingService.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/RAG/RAGIndexingService.swift)
2. [VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift)
3. [VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift)
4. [VivaDicta/Views/SmartSearch/SmartSearchChatView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatView.swift)
5. [VivaDicta/Models/ChatMessage.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Models/ChatMessage.swift)
6. [VivaDicta/VivaDictaApp.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/VivaDictaApp.swift)
