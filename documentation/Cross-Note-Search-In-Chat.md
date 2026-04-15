# Cross-Note Search In Normal Chat

## Overview

VivaDicta supports explicit cross-note retrieval in single-note normal chat.

This lets the user stay inside a regular "Chat with Note" conversation and intentionally pull in relevant context from other notes for the next message only.

Example intents:

- `Did I mention something similar in other notes?`
- `Have I written about burnout elsewhere?`
- `Find related notes and compare them with this one.`

This feature is:

- explicit
- one-shot
- app-controlled
- planner-first

It is not autonomous chat-time tool use.

## User Experience

In single-note normal chat, the composer shows:

- `Search other notes`

This control is shown only when Smart Search is enabled.

If the Smart Search toggle is off, normal chat does not expose cross-note search at all.

When tapped:

- the action is armed for the next send only
- the next message runs the cross-note flow before the final answer call
- the armed state resets immediately after that send

This is a hard allow.

The user decides whether cross-note search is allowed for the turn.

The model does not get to search other notes on ordinary turns.

## Scope

Currently implemented in:

- single-note normal chat

Not implemented yet in:

- multi-note chat
- Smart Search chat

## Core Idea

The app no longer feeds the raw user message directly into notes search.

Instead, the feature uses a two-stage design:

1. A small planner model call derives a focused search query from:
   - the latest user message
   - recent chat context
   - the current note
2. The app runs cross-note retrieval with that focused query.
3. The final answer model call receives the retrieved results and answers naturally.

This means a message like:

- `Did I mention something similar in other notes?`

does not search with that full sentence.

Instead, the planner might derive something like:

- `apple frameworks`
- `burnout`
- `business idea`

and retrieval runs with that focused query.

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
│ App runs planner step                                        │
│ - latest user message                                        │
│ - recent chat turns                                          │
│ - current note text                                          │
│ - outputs shouldSearch + focused searchQuery                 │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ App runs cross-note retrieval with planned query             │
│ - excludes current note                                      │
│ - semantic RAG over indexed chunks                           │
│ - no lexical fallback layer                                  │
│ - no SwiftData keyword scan                                  │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ App builds augmented prompt                                  │
│ - inserts OTHER_NOTES_SEARCH_RESULTS block                   │
│ - includes focused search query used                         │
│ - appends USER QUESTION                                      │
└──────────────────────────────┬────────────────────────────────┘
                               │
                               ▼
┌───────────────────────────────────────────────────────────────┐
│ App sends final prompt to selected model                     │
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

## Step 1 - Search Planning

### Purpose

The planner exists so retrieval does not depend on the raw wording of the user message.

Its job is to infer the real search topic.

### Inputs

The planner receives:

- latest user message
- up to 4 recent non-summary chat messages
- current note text

### Output

The planner returns structured data:

```json
{
  "shouldSearch": true,
  "searchQuery": "apple frameworks",
  "reasoning": "The user is asking whether the topic of the current note appears in other notes."
}
```

### Planner Rules

The planner prompt instructs the model to:

- infer the real search topic from latest message + recent chat + current note
- produce a short focused query
- remove framing such as `did I mention`, `other notes`, `similar`, `search`, `find`, `elsewhere`
- prefer concrete entities, projects, concepts, people, or phrases from the note
- keep the query concise
- return only JSON

### Provider Behavior

The planner is aligned across Apple and cloud chat, but the implementation differs slightly:

- Apple Foundation Models:
  - uses structured generation with `LanguageModelSession.respond(generating:)`
- cloud providers:
  - uses a non-streaming chat request
  - planner prompt asks for JSON only
  - app decodes the JSON result

### Normalization

After the planner responds, the app normalizes the planned query:

- trims whitespace
- collapses repeated whitespace
- removes line breaks and tabs
- caps query length to 80 characters
- if the query becomes empty, search is treated as disabled

### Failure Behavior

If the planner fails, or decides that no focused query can be inferred:

- the app does not run notes retrieval
- the final prompt still includes an explanatory `OTHER_NOTES_SEARCH_RESULTS` block
- the assistant can answer naturally, but without other-note evidence

## Step 2 - Cross-Note Retrieval

Cross-note retrieval is implemented in `NotesSearchToolRuntime.searchNotesPayload(...)`.

This is app-controlled retrieval. It does not call an LLM.

### Data Source

The retrieval layer is intentionally simple:

- semantic RAG search through the local note index

It does not add:

- lexical/original-text fallback matching
- SwiftData keyword predicates
- `enhancedText` search
- `TranscriptionVariation.text` search

This keeps cross-note search aligned with Smart Search and avoids a second custom retrieval stack in normal chat.

### 2.1 Semantic Search

If Smart Search is enabled, the app calls:

- `RAGIndexingService.shared.search(query:topK:)`

This searches the local vector index over semantically chunked note text and returns chunk-level matches that are already mapped back to note IDs.

### 2.2 Note Resolution

RAG returns note identifiers plus chunk excerpts and semantic relevance scores.

The app then:

- excludes the current note
- resolves matched note IDs back to `Transcription` records
- keeps the RAG ordering
- takes up to `4` results

Each final note hit carries:

- note identity
- title
- formatted date
- excerpt from the matched chunk
- source type
- semantic relevance score

## Step 3 - Result Ordering

Cross-note search now uses the ordering already produced by RAG.

That means:

- no secondary lexical ranking formula
- no dual-source boost
- no app-side merge score

This is intentionally simpler and easier to reason about.

## Step 5 - Prompt Injection

The final chat model call receives an augmented prompt block like:

```text
<OTHER_NOTES_SEARCH_RESULTS>
Focused search query used for other notes: apple frameworks

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
Did I mention something similar in other notes?
```

If no matches are found:

```text
<OTHER_NOTES_SEARCH_RESULTS>
Focused search query used for other notes: apple frameworks

No matching notes found outside the note or notes already in the conversation.
</OTHER_NOTES_SEARCH_RESULTS>

USER QUESTION:
Did I mention something similar in other notes?
```

If planning fails or no focused query is inferred:

```text
<OTHER_NOTES_SEARCH_RESULTS>
Other-note search was enabled for this turn, but no focused search query could be inferred from the note and recent chat.
</OTHER_NOTES_SEARCH_RESULTS>

USER QUESTION:
...
```

If retrieval itself fails:

- the app falls back to the original user message without cross-note augmentation

## Important Behavior

- Retrieval happens before the final answer request is sent to the model
- Cross-note retrieval is app-controlled, not autonomous tool use
- The current note is excluded from results
- The feature is one-shot and resets after send
- The final answer model never receives raw retrieval internals like ranking formulas
- The raw user message is not used directly as the retrieval query
- Cross-note search is available only when Smart Search is enabled

## Model Support

This feature works with all providers that already support single-note normal chat, because retrieval happens in app code and the planner step is also app-controlled.

In practice, that includes:

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
- custom OpenAI-compatible endpoints

## Why This Is Explicit Instead Of Autonomous

VivaDicta still contains a parked Apple FM `NotesSearchTool`, but normal chat does not currently rely on that tool path.

Reason:

- autonomous tool behavior was too eager for ordinary current-note questions
- that degraded answer quality

The current design is safer and more predictable:

- user explicitly enables other-note search for the turn
- a planner derives the focused query
- the app performs retrieval
- the final answer model reasons over the retrieved results

The current design is also intentionally simple:

- planner-first
- RAG-only retrieval
- no separate lexical retrieval layer in normal chat

## Citations

Assistant messages created from cross-note search store:

- `sourceTranscriptionIds`
- `sourceCitations`

The normal chat UI reuses the existing citation-pill display to show and open matched notes.

## Key Files

Core files for this feature:

- [VivaDicta/Services/AIEnhance/CrossNoteSearchPlanner.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/CrossNoteSearchPlanner.swift)
- [VivaDicta/Services/AIEnhance/NotesSearchTool.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/NotesSearchTool.swift)
- [VivaDicta/Services/AIEnhance/ChatCrossNoteContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/ChatCrossNoteContextManager.swift)
- [VivaDicta/Services/AIEnhance/ChatContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/ChatContextManager.swift)
- [VivaDicta/Views/Chat/ChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatViewModel.swift)
- [VivaDicta/Views/Chat/ChatView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatView.swift)
- [VivaDicta/Views/Chat/ChatInputBar.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatInputBar.swift)
- [VivaDicta/Services/RAG/RAGIndexingService.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/RAG/RAGIndexingService.swift)

## Future Direction

Likely future additions:

- multi-note chat support
- planner quality tuning based on real conversations
- optional provider-gated autonomous search experiments for stronger models
- a future per-mode toggle such as:
  - `Automatic search in other notes (Experimental)`

Those are not part of the current MVP.
