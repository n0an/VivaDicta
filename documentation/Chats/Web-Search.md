# Web Search Tool

## Overview

VivaDicta integrates web search via the [Exa](https://exa.ai) API. It surfaces in chat as an optional per-turn augmentation that pulls current web facts into the final answer prompt.

Like cross-note search, it exists in two shapes:

- **Explicit web search** - user arms the "Search web" icon for one turn. Planner runs first, then Exa, then augmented prompt, then final answer.
- **Implicit web search** - runs only when the user did not arm explicit search. Apple FM can invoke the `ExaWebSearchTool` directly mid-generation. Cloud providers use a non-streaming tool-decision helper that returns a query the app runs itself.

Smart Chat uses a cut-down version: Apple FM can invoke the tool natively, but there is no arming UX and no `WebSearchPlanner` orchestration.

## Configuration

- API key: stored in iCloud Keychain under `exaAPIKey` (`ExaAPIKeyManager`)
- Settings: `Settings > AI Processing > Chat Tools` (`ChatToolsSettingsView`)
- Feature flag: `WebSearchToolFeature.isEnabled`
- Availability check: `canSearchWeb = WebSearchToolFeature.isEnabled && ExaAPIKeyManager.isConfigured`

If either the feature flag is off or the key is missing, the arming icon is hidden and the runtime returns an `error` payload with an "unavailable" message.

## Surfaces

| Surface | Explicit | Implicit (Apple FM) | Implicit (Cloud) |
|---|---|---|---|
| Single-note chat | Yes | Yes - always attached when key present | Yes - tool-decision helper |
| Multi-note chat | Yes | Yes - always attached when key present | Yes - tool-decision helper |
| Smart Chat | No | Yes - always attached when key present | No - Smart Chat cloud path has no tool-decision helper for web |

## API Client

`ExaSearchClient.search(query:apiKey:)` posts to `https://api.exa.ai/search`:

- `numResults: 5`
- `contents.text.maxCharacters: 500`
- header `x-api-key: <key>`

Returns `[ExaResult]` with `title`, `url`, `text`, `publishedDate`. The first 5 are kept for both prompt injection and tool return.

`ExaWebSearchToolRuntime.searchPayload(query:)` wraps this with:

- `query` trim + empty check
- API key presence check
- typed error handling (invalid URL, invalid response, HTTP 401/403 invalid key, HTTP 429 rate limit)

Output is a `WebSearchPayload { query, status (success/empty/error), results, message }`.

## Arming UX (Normal Chat)

When `canSearchWeb` is true, `ChatInputBar` shows a globe icon alongside the "Search other notes" icon.

- Tap once to arm for the next send
- Arming web disarms cross-note search (they are mutually exclusive)
- Send the message -> planner -> Exa -> augmented prompt
- Armed state resets immediately after send

If the feature is off or the key is missing, the icon is hidden.

## Explicit Path

### Flow

```text
User arms "Search web"
        │
        ▼
User sends message
        │
        ▼
makeWebSearchContext(...)
        │
        ▼
WebSearchPlanner.makePlan(...)
   inputs:
   - latestUserMessage
   - recentMessages (up to 4, non-summary)
   - noteText (current note or assembled multi-note context)
        │
        ▼
Planner output: { shouldSearch, searchQuery, reasoning }
        │
        ├─ planner failed     -> planner-unavailable block, no Exa
        ├─ shouldSearch=false -> no-query-inferred block, no Exa
        └─ shouldSearch=true
                │
                ▼
       ExaWebSearchToolRuntime.searchPayload(query: plannedQuery)
                │
                ▼
       ChatWebSearchContextManager.assembleAugmentedPrompt(
         basePrompt: (user text or post-cross-note prompt),
         plannedQuery:,
         payload:)
                │
                ▼
       Final answer: Apple FM main session OR cloud streaming request
```

### Planner Inputs

`WebSearchPlanner.makePlan(aiService:provider:model:noteText:recentMessages:latestUserMessage:)`:

- `latestUserMessage`
- `recentMessages` - up to 4 prior non-summary messages (same `plannerMessagesForCrossNoteSearch()` helper reused)
- `noteText` - full current note text (single-note) or assembled `<NOTE ...>` blocks (multi-note)

The planner has the note text so it can pull entities and technologies from the note context into the web query.

### Planner Payload

```text
LATEST USER MESSAGE:
...

RECENT CHAT:
User: ...
Assistant: ...

CURRENT NOTE OR NOTES:
...
```

### Planner Output

```json
{
  "shouldSearch": true,
  "searchQuery": "SwiftUI Liquid Glass iOS 26 adoption",
  "reasoning": "User is asking about current adoption data for a technology in the note."
}
```

Apple path: `@Generable WebSearchPlanSchema` with `.greedy` sampling.
Cloud path: non-streaming `AIService.makeChatRequest(...)`, then `extractJSONObject` + JSON decode.

### Query Normalization

- trim
- split whitespace, rejoin single-spaced
- cap at **100** characters (web queries are allowed to be slightly longer than cross-note's 80)
- empty -> `shouldSearch` forced to false

### System Prompt for the Planner

The planner is explicitly instructed to:

- use web search only when online info, current facts, product docs, or release details would help
- strip framing like "search web", "look up", "online", "latest", "current"
- prefer concrete entities/APIs/companies/people from the note
- return plain JSON without markdown fences

### What Goes Into the Final Prompt

`ChatWebSearchContextManager.assembleAugmentedPrompt(basePrompt:plannedQuery:payload:)`:

```text
<WEB_SEARCH_RESULTS>
Focused web search query used: SwiftUI Liquid Glass iOS 26 adoption

The following excerpts come from web search results.

WEB RESULT 1
Title: ...
URL: https://...
Excerpt:
<Exa text, up to ~500 chars>

WEB RESULT 2
Title: ...
URL: https://...
Excerpt:
...
</WEB_SEARCH_RESULTS>

<basePrompt>
```

Notes:

- `basePrompt` can be either the raw user message, or a prompt already augmented by `ChatCrossNoteContextManager` (if both cross-note and web were armed, although the arming UI prevents this - cross-note and web are mutually exclusive per turn)
- up to 5 results, each with title + URL + excerpt (up to 500 chars from Exa)
- web results are wrapped in `<WEB_SEARCH_RESULTS>` tags, just like cross-note uses `<OTHER_NOTES_SEARCH_RESULTS>`

Empty-result variant:

```text
<WEB_SEARCH_RESULTS>
Focused web search query used: <query>

No relevant web results were found.
</WEB_SEARCH_RESULTS>

<basePrompt>
```

Planner-unavailable variant:

```text
<WEB_SEARCH_RESULTS>
<explanatory message>
</WEB_SEARCH_RESULTS>

<basePrompt>
```

Error variant: `basePrompt` is used unchanged (no envelope). `errorMessage` is set on the view model for UI display.

## Implicit Path

Runs only when `allowImplicitTools = !shouldSearchOtherNotes && !shouldSearchWeb` is true - i.e. the user did not arm anything.

### Apple Foundation Models (Normal Chat)

`ChatViewModel.appleFMTools(includeImplicitWebSearch: true)` attaches `ExaWebSearchTool` to the session whenever:

- `WebSearchToolFeature.isEnabled` is true
- `ExaAPIKeyManager.apiKey` exists and is non-empty

The tool is attached **unconditionally** when those two are met, because the tool description is strict enough to self-gate. From `ExaWebSearchTool`:

> Search the web ONLY when the user explicitly asks to look something up online, or asks about current events, news, or real-time facts. Do NOT use this tool to answer questions about the user's notes - those are already in the conversation.

When the model calls `searchWeb(query:)`:

1. Validates non-empty query
2. Calls `ExaAPIClient.search(query:apiKey:)` directly
3. Returns results as `GeneratedContent` with `status`, `query`, `summary` properties formatted as a numbered list with titles, snippets, and URLs

`ExaWebSearchToolRuntime` tracks invocation per-session with a `captureID` passed into the tool init:

- `beginCapture(for:)` clears the flag before a turn
- `markInvoked(for:)` sets it on each tool call
- `consumeDidInvoke(for:)` reads and clears at turn end

The flag is persisted as `didUseWebSearchTool` on the assistant message.

### Cloud Providers (Normal Chat)

`makeImplicitCloudWebSearchContext(...)`:

1. Non-streaming `AIService.makeWebSearchToolDecision(provider:model:systemMessage:messages:)`
2. Routes to `makeAnthropicWebSearchToolDecision` (Anthropic) or `makeOpenAIWebSearchToolDecision` (all others)
3. Helper asks the model whether it wants to search the web and, if yes, what query
4. If non-nil `plannedQuery` returned, app calls `ExaWebSearchToolRuntime.searchPayload(...)` itself
5. App rebuilds prompt via `ChatWebSearchContextManager.assembleAugmentedPrompt(...)` and sends a fresh streaming request

So cloud "implicit" web search is:

- one non-streaming tool-decision helper call
- app-controlled Exa request
- one final streaming answer request with the augmented prompt

Not true provider-side function calling.

### Smart Chat

Smart Chat's `appleFMTools` always includes `ExaWebSearchTool` when the key is present. There is no implicit flow for cloud in Smart Chat - when the user is on a cloud provider in Smart Chat, web search is not available.

## Apple vs Cloud Execution Model Summary

### Explicit, Apple FM

```text
Temporary WebSearchPlanner session (greedy)
        │
        ▼
ExaWebSearchToolRuntime.searchPayload (direct Exa HTTP)
        │
        ▼
Persistent main chat LanguageModelSession receives the augmented prompt
```

### Explicit, Cloud

```text
Non-streaming AIService.makeChatRequest (planner)
        │
        ▼
ExaWebSearchToolRuntime.searchPayload
        │
        ▼
Streaming AIService.makeChatStreamingRequest (augmented prompt + full message history)
```

### Implicit, Apple FM

Single session with `ExaWebSearchTool` attached. The tool may fire zero, one, or more times during one turn.

### Implicit, Cloud

Two sequential HTTP requests: non-streaming tool-decision helper -> streaming final answer.

## Mutual Exclusivity With Cross-Note Search

Per-turn arming is mutually exclusive:

- `toggleCrossNoteSearchArmed()` disarms web
- `toggleWebSearchArmed()` disarms cross-note

Both explicit arming flows set `allowImplicitTools = false`, which means armed turns never also run implicit tools. Unarmed turns run the full implicit pipeline for both tools.

## Failure Cases

| Case | Payload | Prompt envelope |
|---|---|---|
| API key missing | `error` status, "unavailable" message | `basePrompt` used unchanged |
| Empty query | `error`, "cannot be empty" | same |
| Invalid API key (401/403) | `error`, "Invalid Exa API key." | same |
| Rate limit (429) | `error`, "rate limit exceeded" | same |
| Network/unknown error | `error` with error description | same |
| Exa returns 0 results | `empty` | empty block with focused query |
| Planner failed | n/a | planner-unavailable block |
| Planner said `shouldSearch: false` | n/a | no-query-inferred block |

## Logs

Console category `chatViewModel`:

- `Web planner provider=... shouldSearch=... query='...'`
- `Chat - Web search start originalQuery='...' plannedQuery='...'`
- `Chat - Web search found N results for plannedQuery='...'`
- `Chat - Cloud implicit web tool provider=... plannedQuery='...'`
- `Apple FM web tool invoked query='...'` (implicit Apple FM)
- `Web search start query='...'` and `Web search raw results=N` (runtime)

## Key Files

- [VivaDicta/Services/AIEnhance/ExaWebSearchTool.swift](../../VivaDicta/Services/AIEnhance/ExaWebSearchTool.swift)
- [VivaDicta/Services/AIEnhance/WebSearchPlanner.swift](../../VivaDicta/Services/AIEnhance/WebSearchPlanner.swift)
- [VivaDicta/Services/AIEnhance/ChatWebSearchContextManager.swift](../../VivaDicta/Services/AIEnhance/ChatWebSearchContextManager.swift)
- [VivaDicta/Services/AIEnhance/WebSearchToolFeature.swift](../../VivaDicta/Services/AIEnhance/WebSearchToolFeature.swift)
- [VivaDicta/Services/AIEnhance/AIService+Chat.swift](../../VivaDicta/Services/AIEnhance/AIService+Chat.swift)
- [VivaDicta/Views/Chat/ChatViewModel.swift](../../VivaDicta/Views/Chat/ChatViewModel.swift)
- [VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift](../../VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift)
- [VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift](../../VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift)
- [VivaDicta/Views/SettingsScreen/ChatToolsSettingsView.swift](../../VivaDicta/Views/SettingsScreen/ChatToolsSettingsView.swift)
