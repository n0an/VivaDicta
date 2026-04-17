# Smart Search RAG Flow

This document is the short operational view of Smart Search RAG.

If you want the broader architecture and rationale, see:

- [Smart-Search-RAG-Architecture.md](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/documentation/Smart-Search-RAG-Architecture.md)

## Turn Flow

```text
┌──────────────────────────────────────────────────────────────────────┐
│ User sends a message in Smart Search                                │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SmartSearchChatViewModel.sendMessage()                              │
│ - validate provider/model                                           │
│ - create pending user message                                       │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Planner step                                                        │
│ - input: latest message + up to 4 recent messages                   │
│ - output: plannedQuery                                              │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ RAGIndexingService.search(plannedQuery, topK)                       │
│ - semantic vector search                                            │
│ - threshold = 0.25                                                  │
│ - over-fetch topK * 2                                               │
│ - keep strongest chunk per note                                     │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                 ┌─────────────────┴──────────────────┐
                 │                                    │
                 ▼                                    ▼
┌──────────────────────────────┐      ┌────────────────────────────────┐
│ No note hits                 │      │ Note hits found                │
│ - maybe deterministic        │      │ - resolve Transcription models │
│   no-evidence response       │      │ - build source citations       │
└──────────────┬───────────────┘      └──────────────┬─────────────────┘
               │                                      │
               └──────────────────┬───────────────────┘
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SmartSearchContextManager.assembleAugmentedPrompt()                 │
│ - inject focused retrieval query if different                       │
│ - inject SOURCE blocks                                              │
│ - append original USER QUESTION                                     │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Final answer call                                                   │
│ - Apple FM main chat session OR                                     │
│ - cloud streaming request                                           │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Assistant response persisted                                        │
│ - response text                                                     │
│ - source note ids                                                   │
│ - source citations with excerpt + score                             │
└──────────────────────────────────────────────────────────────────────┘
```

## Apple vs Cloud

### Apple FM

```text
planner session  ->  local RAG  ->  main Apple chat session
```

Meaning:

- planner uses a temporary Apple session
- retrieval is local
- final answer goes through the persistent Smart Search Apple session

### Cloud

```text
planner request  ->  local RAG  ->  final streaming chat request
```

Meaning:

- one non-streaming planner request
- retrieval is local
- one final streaming answer request

## Planner Input

Planner input is:

- latest user message
- up to 4 recent non-summary messages

Planner does not receive fixed note text in Smart Search.

So the context window for planning is effectively:

- current latest message
- plus up to 4 previous messages

## What RAG Searches

RAG searches:

- `transcription.text`
- semantically chunked local note content

RAG does not search:

- `enhancedText`
- variations

Current runtime threshold:

- `0.25`

## What Gets Injected

The final LLM does not receive full notes.

It receives:

- all returned note results
- one chunk excerpt per note
- title + date + excerpt
- original user question
- optionally the focused retrieval query that was used

Example:

```text
Here are relevant excerpts from the user's notes:

Focused retrieval query used for note search:
apple frameworks iOS macOS

SOURCE 1
Title: ...
Date: ...
Excerpt:
...

SOURCE 2
Title: ...
Date: ...
Excerpt:
...

USER QUESTION:
Do I have notes about similar thoughts?
```

So the injection rule is:

- all returned note results
- one chunk per note
- never full note text

## Empty Retrieval

If retrieval finds nothing:

- Smart Search may return a deterministic no-evidence reply when the planned query is substantive
- otherwise it can fall back to the raw-question path

## Summary

Smart Search is now:

- planner-first
- RAG-only
- chunk-excerpt injection
- Apple: temporary planner session + persistent chat session
- cloud: planner request + final chat request
