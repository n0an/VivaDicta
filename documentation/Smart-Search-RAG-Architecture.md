# Smart Search RAG Architecture

## Overview

Smart Search is VivaDicta's retrieval-augmented chat mode for searching across the user's transcription notes.

Unlike single-note chat and multi-note chat, Smart Search does not start with a fixed note set. For every user turn, it:

1. Semantically searches the local note index.
2. Maps chunk hits back to source notes.
3. Applies a grounding filter to reject weak or unsubstantiated hits.
4. Injects the surviving chunk excerpts into the prompt.
5. Persists note-level and excerpt-level citations on the assistant message.

The current production setup is:

- Chunking and indexing via `LumoKit`
- Vector search via `VecturaKit`
- Embeddings via `SwiftEmbedder`
- Current embedding model: `minishlab/potion-base-32M`
- Current chunking: semantic, `chunkSize = 500`, `overlap = 15%`
- Current retrieval: always search, then ground/filter
- Current prompt injection: chunk excerpts, not full notes

Smart Search intentionally does not use a pre-retrieval router at the moment. The local corpus is small enough that always searching is acceptable, and earlier router experiments introduced false negatives for vague memory-recall questions.

## Why This Architecture Exists

The core problem Smart Search is trying to solve is:

- let the user ask open-ended questions about all notes
- keep the answer grounded in real note content
- avoid stuffing entire notes into every prompt
- keep citations understandable and tappable

This led to several deliberate design choices:

- Index raw note text, not `enhancedText`
- Retrieve chunks, not entire notes
- Inject chunk excerpts into the LLM prompt
- Keep note-level references in the UI
- Apply lexical grounding after semantic retrieval

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              Smart Search UI                              │
│                                                                            │
│  SmartSearchChatView                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ Chat bubbles                                                        │  │
│  │ "Searching notes..." indicator                                      │  │
│  │ Citation pills: date + matched excerpt preview                      │  │
│  └──────────────────────────────┬───────────────────────────────────────┘  │
└─────────────────────────────────│──────────────────────────────────────────┘
                                  │
                                  ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                        SmartSearchChatViewModel                            │
│                                                                            │
│  sendMessage()                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ 1. semantic search via RAGIndexingService                           │  │
│  │ 2. grounding filter                                                 │  │
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

### `SmartSearchChatViewModel`

File: [VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift)

Responsibilities:

- execute retrieval for each user message
- apply the grounding filter
- resolve note models for retrieved hits
- assemble source citations
- build the augmented prompt
- send the final request through `AIService` or Apple Foundation Models

### `SmartSearchContextManager`

File: [VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchContextManager.swift)

Responsibilities:

- define Smart Search system prompt
- wrap retrieved excerpts in `<NOTE>` blocks
- format the augmented prompt for cloud and Apple FM chat paths

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
- search threshold: `0.3`
- default results: `5`

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

Smart Search currently always performs retrieval for each user message, then applies grounding afterward.

```
┌──────────────────────────────────────────────────────────────────────────┐
│ User sends message                                                      │
└──────────────────────────────┬───────────────────────────────────────────┘
                               ▼
                SmartSearchChatViewModel.sendMessage()
                               │
                               ▼
               RAGIndexingService.search(query:, topK: 5)
                               │
                               ▼
      semanticSearch(query, numResults: topK * 2, threshold: 0.3)
                               │
                               ▼
                    raw chunk hits from vector DB
                               │
                               ▼
              map chunk IDs back to parent transcription IDs
                               │
                               ▼
               keep best-scoring chunk per transcription
                               │
                               ▼
                     grounding filter runs afterward
                               │
             ┌─────────────────┴──────────────────┐
             │                                    │
             ▼                                    ▼
       no grounded hits                     grounded hits remain
             │                                    │
             ▼                                    ▼
      prompt uses raw query            prompt includes <NOTE> excerpts
```

### Search details

`RAGIndexingService.search(...)` currently does the following:

- uses threshold `0.3`
- over-fetches `topK * 2` chunk hits
- maps raw chunk hits back to notes using persisted chunk mapping
- deduplicates by note, keeping the highest-scoring chunk per note
- sorts final results by score

This means Smart Search is currently a:

- chunk-level retrieval system
- note-level deduplication system
- excerpt-level prompt injection system

## Chunk Injection Instead of Full Note Injection

Smart Search used to retrieve by chunk but inject full notes into the model prompt.

That is no longer the case.

Today Smart Search injects:

- only the matched chunk excerpt for each grounded hit

It does **not** inject:

- the full deduplicated note body

Prompt assembly looks like:

```xml
<NOTE id="1" title="First line of the note" date="Apr 12, 2026 at 8:42 PM">
[matched chunk excerpt]
</NOTE>
```

This happens in `SmartSearchContextManager.assembleAugmentedPrompt(...)`.

Benefits:

- less prompt noise
- lower token usage
- more faithful grounding to the retrieved evidence
- clearer citation UX

Current limitation:

- there is no `-1 / hit / +1` chunk window yet
- only the single best chunk per note is injected

## The Grounding Filter

The grounding filter is a second-stage app-side check after semantic retrieval.

It lives in `SmartSearchChatViewModel.groundedSearchResults(...)`.

### Why it exists

Semantic retrieval alone is sometimes too fuzzy.

Examples observed during testing:

- vague queries like `board games` can retrieve unrelated conversational notes
- a correct note can be present in the hit set, but a wrong note may rank higher

The grounding filter keeps semantic retrieval honest by requiring lexical evidence inside the retrieved excerpt.

### How it works

1. Normalize the user query into tokens.
2. Remove stop words and meta-query words.
3. Normalize each retrieved chunk excerpt into tokens.
4. Compute lexical overlap between query terms and excerpt terms.
5. Accept only excerpts with enough overlap.

Current logic:

- `requiredMatches = min(max(1, queryTerms.count), 2)`
- if query has one substantive term, a single overlap can pass
- single-term matches also need `relevanceScore >= 0.45` for the low-bar citation path

Examples of words removed before grounding:

- English: `did`, `maybe`, `something`, `mention`, `mentioned`, `say`, `said`, `talk`, `talked`, `tell`, `told`
- Russian: `говорил`, `говорила`, `говорили`, `упоминал`, `упоминала`, `упоминали`, `сказал`, `сказала`, `сказали`

### Why this matters

Without grounding:

- Smart Search can attach unrelated citations
- the LLM may over-interpret semantically loose hits

With grounding:

- weak hits are discarded before prompt injection
- vague-query junk citations are suppressed
- correct lower-ranked hits can survive when the top semantic hit is lexically unsupported

## Why We Do Not Use a Router

A pre-retrieval router was tested and removed.

Why it was removed:

- it introduced false negatives for vague memory-recall questions
- examples like `Maybe something about chess?` were sometimes classified as "skip retrieval"
- Smart Search is local and relatively cheap, so always retrieving is acceptable

Current strategy is simpler:

- always retrieve
- ground/filter before injection

This is the current intended behavior.

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

## Model History and Current Choice

The current production choice is:

- `SwiftEmbedder` with `minishlab/potion-base-32M`

Why this is the current winner:

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

Those experiments informed the current choice, but the app currently ships on the simpler and more stable `potion-base-32M` path.

## Current Strengths

- fully local note retrieval
- excerpt injection instead of full-note stuffing
- deterministic incremental indexing
- note-aware citations with excerpt previews
- grounding filter catches many fuzzy semantic misses

## Current Limitations

- retrieval still always runs for every user message
- search threshold is still relatively permissive at `0.3`
- deduplication keeps only one best chunk per note
- there is no local context window around the matched chunk
- grounding is lexical, not semantic, so it is a pragmatic guardrail rather than a full relevance model

## Likely Next Improvements

The most likely next improvements are in retrieval logic, not embedder swaps:

1. Improve per-note chunk selection
   - let the best grounded chunk win inside a note
   - or keep multiple chunks per note before final prompt assembly

2. Add optional local chunk window
   - previous / current / next chunk
   - only if chunk-only context proves too narrow

3. Tune citation suppression further
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
