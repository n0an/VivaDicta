# Cross-Note Search In Chat

## Overview

VivaDicta supports explicit cross-note retrieval inside normal chat surfaces.

Today this is implemented in:

- single-note chat
- multi-note chat

It is not autonomous tool use.

The user explicitly enables it for one turn with the search icon in the input row, then the app runs a planner-first retrieval flow before the final answer call.

## User Experience

When Smart Search is enabled, normal chat shows a compact `Search other notes` icon inside the input row.

Behavior:

- tap once to arm cross-note search for the next send
- send the message
- app performs planning and retrieval before the final answer call
- armed state resets immediately after the send

When Smart Search is disabled:

- the icon is hidden
- cross-note search cannot be armed

This is a hard allow:

- ordinary chat turns do not search other notes
- only explicitly armed turns do

## Scope

Implemented:

- single-note normal chat
- multi-note normal chat

Not used in:

- Smart Search chat

Smart Search has its own planner-first RAG flow documented separately in the Smart Search RAG docs.

## Core Idea

The app does not feed the raw user sentence directly into retrieval.

Instead, the flow is:

1. Planner derives a focused search query.
2. Local RAG searches other notes with that planned query.
3. Retrieved excerpts are injected into the final answer prompt.
4. The main chat model answers naturally.

Example:

- user message: `Did I mention something similar in other notes?`
- planner output: `apple frameworks`
- retrieval query: `apple frameworks`

## High-Level Flow

```text
┌──────────────────────────────────────────────────────────────────────┐
│ User is in single-note or multi-note normal chat                    │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ User taps Search other notes icon                                   │
│ - one-shot armed state becomes true                                 │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ User sends message                                                  │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Planner step                                                        │
│ - latest user message                                               │
│ - up to 4 recent non-summary messages                               │
│ - current note context already in this chat                         │
│ - output: shouldSearch + plannedQuery                               │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Cross-note retrieval                                                │
│ - local RAG search only                                             │
│ - query = plannedQuery                                              │
│ - exclude note(s) already in this chat                              │
│ - keep up to 4 note results                                         │
│ - one chunk excerpt per note                                        │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ App builds augmented prompt                                         │
│ - OTHER_NOTES_SEARCH_RESULTS block                                  │
│ - focused search query used                                         │
│ - note title/date/excerpt blocks                                    │
│ - original user question appended                                   │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Final answer call                                                   │
│ - Apple FM main chat session OR                                     │
│ - cloud streaming chat request                                      │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Assistant response persisted                                        │
│ - response text                                                     │
│ - source note ids                                                   │
│ - excerpt-level citations                                           │
└──────────────────────────────────────────────────────────────────────┘
```

## Planner Input

Cross-note search planning receives more than just the latest user sentence.

Planner inputs:

- latest user message
- up to 4 recent non-summary chat messages
- current note context already in the chat

That means the planner window is:

- current message
- plus up to 4 previous messages

Not the entire chat history.

### Single-Note Chat

`current note context` means the full current note text:

- `assembledNoteText`
- which is `transcription.text`

### Multi-Note Chat

`current note context` means the full assembled multi-note context:

- `assembledNoteText`
- which is `conversation.noteContext`
- this contains the selected notes already included in that multi-note chat

## Planner Payload Shape

The planner payload is plain text with labeled sections:

```text
LATEST USER MESSAGE:
...

RECENT CHAT:
User: ...
Assistant: ...

CURRENT NOTE:
...
```

For multi-note chat, `CURRENT NOTE` is actually the assembled context for all notes already in the conversation.

## Planner Output

The planner returns structured JSON-like data:

```json
{
  "shouldSearch": true,
  "searchQuery": "apple frameworks",
  "reasoning": "The user is asking whether the topic of the current chat appears in other notes."
}
```

Normalization after planning:

- trim whitespace
- collapse repeated whitespace
- remove line breaks and tabs
- cap to 80 characters
- if empty after normalization, search is treated as disabled

## Retrieval

Cross-note retrieval is implemented in `NotesSearchToolRuntime.searchNotesPayload(...)`.

Important points:

- retrieval is local and app-controlled
- retrieval is RAG-only
- there is no keyword fallback
- there is no SwiftData keyword predicate search
- there is no search over `enhancedText`
- there is no search over `TranscriptionVariation`

The app calls:

- `RAGIndexingService.shared.search(query: plannedQuery, topK: 8)`

Then it:

- filters out notes already in the current chat context
- resolves note ids back to `Transcription`
- keeps up to 4 results

## What Gets Injected

The final model does not receive full notes from cross-note retrieval.

It receives:

- up to 4 note results
- one excerpt per note
- each excerpt derived from the matched RAG chunk

So the injection model is:

- all returned note results are included
- each note contributes one chunk excerpt
- not multiple chunks per note
- not full note text

Injected shape:

```text
<OTHER_NOTES_SEARCH_RESULTS>
Focused search query used for other notes: apple frameworks

The following excerpts come from other notes outside the notes already in this chat context.

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

## Apple vs Cloud Execution Model

The planner and the final answer call are intentionally separated.

### Apple FM

Apple uses two different `LanguageModelSession` objects:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Apple FM cross-note turn                                            │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Temporary planner session                                           │
│ - derive plannedQuery                                               │
│ - no transcript persistence into main chat                          │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Local RAG search                                                    │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Persistent main Apple chat session                                  │
│ - receives final augmented prompt                                   │
│ - continues normal conversation transcript                          │
└──────────────────────────────────────────────────────────────────────┘
```

So for Apple:

- planner uses a separate temporary session
- final answer uses the persistent main chat session
- search itself is local, not an Apple session

### Cloud Providers

Cloud providers do not have a persistent provider-side session in our app code.

Instead, a cross-note turn is:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Cloud cross-note turn                                               │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Planner request                                                     │
│ - non-streaming makeChatRequest(...)                                │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Local RAG search                                                    │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Final chat request                                                  │
│ - streaming makeChatStreamingRequest(...)                           │
│ - full conversation continuity comes from sent messages             │
└──────────────────────────────────────────────────────────────────────┘
```

So for cloud:

- no persistent model session
- one planner request
- one final answer request
- local RAG in between

## Single-Note vs Multi-Note Exclusions

Single-note chat excludes:

- the one current note in that conversation

Multi-note chat excludes:

- all notes already included in that multi-note conversation

This prevents the feature from “finding” notes that are already in scope for the current chat.

## Failure and Empty Cases

Planner failure:

- no search runs
- final prompt includes a planner-unavailable message block

Planner decides no search:

- no search runs
- final prompt includes a no-query-inferred message block

Search returns zero notes:

- final prompt includes an explicit empty-result block
- the final model still answers naturally, but without other-note evidence

Smart Search disabled:

- icon is hidden from normal chat
- cross-note search cannot be armed
- runtime search API returns an error if somehow invoked anyway

## What This Is Not

Current cross-note search is not:

- automatic model-initiated tool use
- Apple FM tool calling in the live chat path
- hybrid semantic + keyword merge
- full-note injection

The old tool type still exists in code as a parked Apple FM tool, but the active chat runtime path is planner-first + local RAG + final answer prompt injection.

## Key Files

- [VivaDicta/Views/Chat/ChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatViewModel.swift)
- [VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift)
- [VivaDicta/Services/AIEnhance/CrossNoteSearchPlanner.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/CrossNoteSearchPlanner.swift)
- [VivaDicta/Services/AIEnhance/NotesSearchTool.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/NotesSearchTool.swift)
- [VivaDicta/Services/AIEnhance/ChatCrossNoteContextManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/AIEnhance/ChatCrossNoteContextManager.swift)
- [VivaDicta/Services/RAG/RAGIndexingService.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Services/RAG/RAGIndexingService.swift)
