# App Review Request Architecture

## Overview

VivaDicta uses a centralized in-app review request system built around `RateAppManager`.

The current design goal is:

- ask for App Store reviews only after positive product outcomes
- throttle requests conservatively enough to avoid annoyance
- keep the actual StoreKit prompt presentation in one place
- support success signals from both the main app and extensions

This document covers:

- the current shipped review request flow
- where review requests are triggered today
- why app start is still part of the system
- how chats and Smart Search should feed the system in the future

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

### Successful transcription flow

File:
- [VivaDicta/Views/RecordViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/RecordViewModel.swift)

Review requests are attempted after:

- successful transcription and save
- successful save when enhancement is cancelled but the transcription is still persisted

This is one of the strongest current success signals because it reflects core product value.

### Successful retranscription

File:
- [VivaDicta/Views/TranscriptionDetailView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionDetailView.swift)

Review requests are attempted after:

- successful retranscribe of an existing note

### Successful AI variation generation

File:
- [VivaDicta/Views/TranscriptionDetailView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionDetailView.swift)

Review requests are attempted after:

- successful generation of a new AI variation
- successful regeneration of an existing variation

This captures value from AI enhancement, not just transcription.

## Keyboard Extension Deferred Flow

Files:
- [VivaDicta/Shared/AppGroupCoordinator.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Shared/AppGroupCoordinator.swift)
- [documentation/AppGroupCoordinator-Architecture.md](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/documentation/AppGroupCoordinator-Architecture.md)

The keyboard extension cannot reliably present the review prompt itself, so VivaDicta uses a deferred handoff:

1. keyboard records a first successful use
2. `AppGroupCoordinator` stores a one-time success flag
3. main app consumes that flag on a later launch
4. main app calls `RateAppManager.requestReviewIfAppropriate()`

Why this is important:

- keyboard-heavy users may get most of the product value outside the main app
- the main app still provides the safest and most predictable presentation moment

## Current Architecture Summary

Today the system is best understood as:

- one central review prompt manager
- several positive outcome triggers
- one deferred delivery path for keyboard success
- one app-start fallback to present in a safe foreground moment

High-level flow:

```text
Positive product outcome
    ->
Feature calls RateAppManager
    ->
RateAppManager checks launch/install/cooldown gates
    ->
If eligible, request StoreKit review in active scene
```

## Why Chats Are Not Yet Part Of The Current System

Chats are implemented, but this surface is not yet treated as a review trigger source in the current shipped system.

That is intentional for now because:

- chat UX is still evolving
- chat success is harder to define than transcription success
- weak triggers inside chat would risk noisy prompts

Examples of bad chat triggers:

- opening a chat
- sending the first message
- greeting-only interactions
- failed responses
- no-evidence Smart Search answers

## Recommended Future Direction For Chats And Smart Search

The recommended architecture is:

- chats and Smart Search should not call StoreKit directly
- they should emit positive events into the same centralized system
- `RateAppManager` should decide whether enough value has been demonstrated to ask for a review

This means evolving from simple direct trigger calls to a lightweight event-driven model.

### Good future positive events

These are the strongest candidates:

- `smartSearchBarResultOpened`
  - user searched in `Smart` or `All`
  - semantic results existed
  - user opened a note from the Smart results section

- `smartSearchChatAnswerWithSources`
  - Smart Search answer succeeded
  - answer had citations
  - answer was not an error and not a no-evidence fallback

- `smartSearchCitationTap`
  - user tapped a citation chip and opened the source note

- `singleNoteChatSessionSuccess`
  - several successful turns
  - no error-heavy session

- `multiNoteChatSessionSuccess`
  - several successful turns across multiple notes
  - especially strong when the answer is clearly synthetic and useful

### Events that should not count

- chat opened
- first message sent
- empty Smart Search results
- no-evidence fallback
- cancelled or failed requests
- generic greetings

## Recommended Delivery Strategy

Even after chats and Smart Search begin generating positive events, the actual StoreKit prompt should still be shown only at calm moments.

Good delivery moments:

- app start after a recent positive event
- leaving a successful chat session
- after returning from a Smart Search result or citation tap

Bad delivery moments:

- while a response is streaming
- while the keyboard is visible
- in the middle of a chat exchange
- immediately after an error or weak result

## Suggested Next Evolution

The most likely future improvement is to add a small event-scoring layer to `RateAppManager`.

Conceptually:

```text
positive event recorded
    ->
recent event score increases
    ->
RateAppManager checks:
    - install age
    - launch history
    - cooldown
    - score threshold
    ->
StoreKit review request if eligible
```

Benefits:

- lets different surfaces contribute value without each owning prompt logic
- makes Smart Search and chats additive rather than spammy
- keeps review policy centralized and tunable

## Files To Read First

If you need to change the review request system, start here:

1. [VivaDicta/Utilities/RateAppManager.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Utilities/RateAppManager.swift)
2. [VivaDicta/Views/MainView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/MainView.swift)
3. [VivaDicta/Views/RecordViewModel.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/RecordViewModel.swift)
4. [VivaDicta/Views/TranscriptionDetailView.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Views/TranscriptionDetailView.swift)
5. [VivaDicta/Shared/AppGroupCoordinator.swift](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/VivaDicta/Shared/AppGroupCoordinator.swift)
6. [documentation/AppGroupCoordinator-Architecture.md](/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta/documentation/AppGroupCoordinator-Architecture.md)
