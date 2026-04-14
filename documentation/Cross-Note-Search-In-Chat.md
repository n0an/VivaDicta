# Cross-Note Search In Normal Chat

## Overview

VivaDicta now supports explicit cross-note retrieval in single-note normal chat.

This lets the user stay inside a normal "Chat with Note" conversation and intentionally pull in relevant context from other notes for the next message only.

Example user intent:

- `Did I mention something similar in other notes?`
- `Have I written about burnout elsewhere?`
- `Find related notes and compare them with this one.`

This feature is intentionally explicit and app-controlled.

It is not autonomous model tool use.

## What The User Sees

In single-note normal chat, the composer shows a subtle action:

- `Search other notes`

When tapped:

- the action becomes armed for the next send only
- the next message will search other notes before the LLM request is sent
- the armed state resets immediately after that send

This is a one-shot hard allow.

The model does not decide whether to search.

## Scope

Currently implemented in:

- single-note normal chat

Not implemented yet in:

- multi-note chat
- Smart Search chat

## High-Level Flow

```text
┌───────────────────────────────────────────────────────────────┐
│ User is in single-note normal chat                           │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ User taps "Search other notes"                               │
│ - one-shot armed state becomes true                          │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ User sends chat message                                      │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ App runs cross-note retrieval before the LLM call            │
│ - excludes current note                                      │
│ - runs semantic RAG search when available                    │
│ - runs SwiftData keyword search                              │
│ - merges and ranks hits                                      │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ App builds augmented prompt                                  │
│ - inserts OTHER_NOTES_SEARCH_RESULTS block                   │
│ - appends USER QUESTION                                      │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ App sends final prompt to the selected model                 │
│ - Apple FM or cloud provider                                 │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ Assistant response is saved with citations                   │
│ - source note ids                                            │
│ - excerpt-level citations                                    │
└───────────────────────────────────────────────────────────────┘
```

## Important Behavior

- Retrieval happens before sending the message to the LLM
- Retrieval is app-controlled, not model-controlled
- The current note is excluded from results
- The feature is one-shot and resets after send
- If no other-note matches are found, the app still injects a no-hit block into the prompt

## Retrieval Strategy

Cross-note retrieval is hybrid.

It uses:

- semantic RAG search through the local note index
- direct keyword search through SwiftData-backed content

### 1. Semantic search via RAG

If Smart Search is enabled, the app first calls:

- `RAGIndexingService.shared.search(query:topK:)`

This searches the existing local vector index over note chunks and returns semantic matches.

### 2. SwiftData keyword search

The app also performs direct keyword matching through SwiftData-backed data:

- `Transcription.text`
- `Transcription.enhancedText`
- `TranscriptionVariation.text`

This helps in cases where:

- semantic search misses an exact phrase
- RAG is disabled
- the user searches for a very specific string

### 3. Merge and rank

The app merges semantic and keyword matches by note id and ranks them.

Behavior:

- current note is excluded
- results are limited to a small set of best hits
- each hit gets a short excerpt
- excerpt-level citation metadata is preserved

## Prompt Injection

If cross-note search is armed for the turn, the app builds an augmented prompt block like this:

```text
<OTHER_NOTES_SEARCH_RESULTS>
The following excerpts come from other notes outside the current note.

OTHER NOTE 1
Title: ...
Date: ...
Excerpt:
...

OTHER NOTE 2
Title: ...
Date: ...
Excerpt:
...
</OTHER_NOTES_SEARCH_RESULTS>

USER QUESTION:
...
```

If no matches are found, the injected block becomes:

```text
<OTHER_NOTES_SEARCH_RESULTS>
No matching notes found outside the note or notes already in the conversation.
</OTHER_NOTES_SEARCH_RESULTS>

USER QUESTION:
...
```

If retrieval fails, the app falls back to the original user message without cross-note augmentation.

## Model Support

This feature works with all providers that already support single-note normal chat, because the retrieval happens in app code before the model request.

That means the model does not need native tool support to use this feature.

In practice, it works with:

- Apple Foundation Models
- Anthropic
- OpenAI
- Gemini
- Groq
- Mistral
- OpenRouter
- Grok
- Cerebras
- Cohere
- Z.AI
- Kimi
- Vercel AI Gateway
- HuggingFace
- GitHub Copilot
- Ollama
- Custom OpenAI-compatible endpoints

## Why This Is Explicit Instead Of Autonomous

VivaDicta already contains a parked Apple FM `NotesSearchTool`, but it is intentionally not attached to normal chat sessions.

Reason:

- Apple FM used it too eagerly for current-note questions
- that degraded answer quality

So the current cross-note chat feature uses hard allow instead:

- user explicitly asks the app to search other notes for the next turn
- app performs retrieval
- model reasons over injected results

This keeps behavior predictable and prevents unwanted searches on ordinary turns.

## Citations

Assistant messages created from cross-note search store:

- `sourceTranscriptionIds`
- `sourceCitations`

The normal chat UI reuses the existing citation-pill display to show and open matched notes.

## Key Files

Core files for this feature:

- [VivaDicta/Services/AIEnhance/NotesSearchTool.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/NotesSearchTool.swift)
- [VivaDicta/Services/AIEnhance/ChatCrossNoteContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/ChatCrossNoteContextManager.swift)
- [VivaDicta/Services/AIEnhance/ChatContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/ChatContextManager.swift)
- [VivaDicta/Views/Chat/ChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatViewModel.swift)
- [VivaDicta/Views/Chat/ChatView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatView.swift)
- [VivaDicta/Views/Chat/ChatInputBar.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatInputBar.swift)

## Future Direction

Possible future additions:

- multi-note chat support
- per-mode toggle:
  - `Automatic search in other notes (Experimental)`
- provider-gated autonomous cross-note search for stronger models

Those are not part of the current MVP.
