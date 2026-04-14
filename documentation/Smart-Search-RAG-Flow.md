# Smart Search RAG Flow

This document summarizes the high-level Smart Search RAG pipeline in VivaDicta.

## Architecture

```text
┌──────────────────────────────────────────────────────────────────────┐
│ User sends a message in Smart Search chat                           │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SmartSearchChatViewModel.sendMessage()                              │
│ - validate provider/model                                           │
│ - create pending user message                                       │
│ - choose retrieval size: Apple = 3, Cloud = 5                      │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ RAGIndexingService.search(query, topK)                              │
│ - ensure local index is ready                                       │
│ - semantic vector search over note chunks                           │
│ - threshold = 0.4                                                   │
│ - over-fetch topK * 2                                               │
│ - map chunk ids back to note ids                                    │
│ - keep best chunk per note                                          │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                ┌──────────────────┴──────────────────┐
                │                                     │
                ▼                                     ▼
┌──────────────────────────────┐      ┌────────────────────────────────┐
│ No retrieval hits            │      │ Retrieval hits found           │
│ - use raw user question      │      │ - resolve Transcription models │
│ - no source citations        │      │ - build source citations       │
└──────────────┬───────────────┘      └──────────────┬─────────────────┘
               │                                      │
               └──────────────────┬───────────────────┘
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SmartSearchContextManager.assembleAugmentedPrompt()                 │
│ - inject SOURCE blocks                                              │
│ - each block contains title, date, excerpt                          │
│ - append USER QUESTION                                              │
│ - if 0 usable excerpts, return raw query                            │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ LLM request                                                         │
│ - Cloud: system prompt + message history + latest augmented turn    │
│ - Apple FM: system prompt in session + latest augmented turn        │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Assistant response persisted                                        │
│ - response text                                                     │
│ - source note ids                                                   │
│ - source citations with excerpt + relevance                         │
└──────────────────────────────────────────────────────────────────────┘
```

## What gets indexed

- Smart Search indexes `transcription.text`
- It does not index `enhancedText`
- It does not index `TranscriptionVariation`
- Chunking is semantic with `chunkSize = 500` and `overlap = 15%`
- Embeddings use `minishlab/potion-base-32M`

## When indexing happens

- On app launch via `indexAllIfNeeded()`
- When a note is created
- When a note is appended to or edited
- When a note is retranscribed
- When a note is deleted, its chunks are removed from the index

## What gets injected into the LLM

### Smart Search system prompt

This is the exact system prompt used by Smart Search:

```text
You are a helpful AI assistant with access to the user's voice transcription notes.
Relevant note excerpts are retrieved automatically for each question and provided in source sections.

Guidelines:
- Answer questions using the provided note context
- When referencing a specific note, mention its title or date
- The provided source sections are excerpts, not always full notes
- Never mention prompt structure, source numbering, or internal formatting in your answer
- If the provided notes don't contain enough information to answer, say so clearly in plain natural language
- You may combine information from multiple notes to form a complete answer
- Keep responses concise unless the user asks for detail
- Do not use long em-dashes; use normal hyphens instead
- Do not fabricate information that isn't in the provided notes
```

### The retrieved context is injected as plain text:

```text
Here are relevant excerpts from the user's notes:

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
...
```

Important behavior:

- Retrieval is performed for every submitted user turn
- Retrieval happens before the LLM call
- Only the latest user turn gets fresh retrieved context injected
- Older chat turns remain as their original text in history
- If retrieval finds nothing, the raw question is sent without note excerpts
