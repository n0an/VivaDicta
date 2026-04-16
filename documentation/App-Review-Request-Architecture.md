# App Review Request Architecture

## Overview

VivaDicta uses a centralized in-app review request system built around `RateAppManager`.

The current design goal is:

- ask for App Store reviews only after positive product outcomes
- throttle requests conservatively enough to avoid annoyance
- keep the actual StoreKit prompt presentation in one place
- support success signals from both the main app and extensions

## Core Component

Primary file:
- [VivaDicta/Utilities/RateAppManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Utilities/RateAppManager.swift)

`RateAppManager` is the single authority responsible for calling StoreKit review UI.

Current responsibilities:

- track the last review request date
- enforce minimum install-age and launch-count gates
- enforce cooldown between requests
- present the StoreKit review prompt in the active foreground scene

## Current Gating Rules

Current configuration in `RateAppManager`:

- minimum launch count: `3`
- minimum days since first launch: `1`
- wide fallback minimum days since first launch: `14`
- minimum days between requests: `60`

Two request paths exist today:

1. Standard path
   - requires launch count, install age, and cooldown to pass

2. Wide fallback path
   - requires only install age and cooldown
   - exists to catch passive users who may not launch frequently enough

## Current Trigger Points

### App start

File:
- [VivaDicta/Views/MainView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/MainView.swift)

On app start, VivaDicta waits briefly, then calls:

- `RateAppManager.requestReviewOnAppStartIfAppropriate(transcriptionCount:)`

This path also checks that the user already has at least one saved transcription.

Why this exists:

- it gives the app a safe foreground moment to present the StoreKit prompt
- it supports users who primarily use the keyboard extension and only occasionally open the main app

### Keyboard extension deferred flow

Files:
- [VivaDicta/Views/MainView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/MainView.swift)
- [VivaDicta/Shared/AppGroupCoordinator.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Shared/AppGroupCoordinator.swift)

The keyboard extension cannot reliably present the review prompt itself, so VivaDicta uses a deferred handoff:

1. keyboard records a first successful use
2. `AppGroupCoordinator` stores a one-time success flag
3. main app consumes that flag on a later launch
4. main app calls `RateAppManager.requestReviewIfAppropriate()`

### Successful transcription

File:
- [VivaDicta/Views/RecordViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/RecordViewModel.swift)

Review requests are attempted after:

- successful transcription and save (line ~623)
- successful save when enhancement completes (line ~783)

This is one of the strongest success signals because it reflects core product value.

### Successful retranscription

File:
- [VivaDicta/Views/TranscriptionDetailView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionDetailView.swift)

Review requests are attempted after:

- successful retranscribe of an existing note (line ~857)

### Successful AI variation generation

File:
- [VivaDicta/Views/TranscriptionDetailView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionDetailView.swift)

Review requests are attempted after:

- successful generation or regeneration of an AI variation (line ~1078)

### Single-note chat session

File:
- [VivaDicta/Views/Chat/ChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatViewModel.swift)

Uses a session-based threshold:

- counts successful AI replies per session
- requests review after `reviewReplyThreshold` (currently 3) successful replies
- only requests once per session (`hasRequestedReviewForSession` flag)
- counters reset when chat is cleared

### Multi-note chat session

File:
- [VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift)

Same session-based pattern as single-note chat:

- threshold is `reviewReplyThreshold` (currently 2, lower than single-note because multi-note queries tend to be more complex and demonstrate higher engagement)
- only requests once per session
- counters reset when chat is cleared

### Smart Search chat - answer with sources

File:
- [VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift)

Review requested after a Smart Search answer that includes source citations (line ~350). Answers without citations (no-evidence fallback) are not treated as positive signals.

### Smart Search chat - citation tap

File:
- [VivaDicta/Views/SmartSearch/SmartSearchChatView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatView.swift)

Review requested when the user taps a citation pill to navigate to the source transcription (line ~231). This indicates the user found the Smart Search result useful enough to explore the source.

### Semantic search result opened

File:
- [VivaDicta/Views/TranscriptionsContentView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionsContentView.swift)

Review requested when the user opens a transcription from search results that included a semantic score (line ~844). This captures the moment a user finds a relevant note through semantic search.

## Trigger Summary

| # | Trigger | File | Signal type |
|---|---------|------|-------------|
| 1 | App start | MainView | Fallback with transcription count gate |
| 2 | Keyboard deferred | MainView + AppGroupCoordinator | First keyboard success, deferred to main app |
| 3 | Transcription saved | RecordViewModel | Core value - transcription complete |
| 4 | Enhanced transcription saved | RecordViewModel | Core value - transcription + AI complete |
| 5 | Retranscription | TranscriptionDetailView | User re-processed existing note |
| 6 | AI variation generated | TranscriptionDetailView | AI enhancement value |
| 7 | Single-note chat | ChatViewModel | 3+ successful replies in session |
| 8 | Multi-note chat | MultiNoteChatViewModel | 2+ successful replies in session |
| 9 | Smart Search answer with sources | SmartSearchChatViewModel | Answer had citations |
| 10 | Smart Search citation tap | SmartSearchChatView | User opened source note from citation |
| 11 | Semantic search result opened | TranscriptionsContentView | User opened note from semantic results |

## Files To Read First

If you need to change the review request system, start here:

1. [VivaDicta/Utilities/RateAppManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Utilities/RateAppManager.swift)
2. [VivaDicta/Views/MainView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/MainView.swift)
3. [VivaDicta/Views/RecordViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/RecordViewModel.swift)
4. [VivaDicta/Views/TranscriptionDetailView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionDetailView.swift)
5. [VivaDicta/Views/Chat/ChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/Chat/ChatViewModel.swift)
6. [VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift)
7. [VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift)
8. [VivaDicta/Views/SmartSearch/SmartSearchChatView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/SmartSearch/SmartSearchChatView.swift)
9. [VivaDicta/Views/TranscriptionsContentView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionsContentView.swift)
10. [VivaDicta/Shared/AppGroupCoordinator.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Shared/AppGroupCoordinator.swift)
