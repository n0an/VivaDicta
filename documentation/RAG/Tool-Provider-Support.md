# Tool Provider Support

## Overview

This document maps VivaDicta chat and RAG tools to the AI providers currently supported in the app.

There are 3 distinct tool flows:

1. Normal chat explicit cross-note search
2. Normal chat explicit web search
3. Smart Search note retrieval and Smart Search web tool use

These flows are not all implemented the same way.

## How Tooling Works

### Normal Chat - Single-Note and Multi-Note

For standard chat surfaces, the app supports:

- `Search other notes`
- `Search web`

Those features are primarily planner-first and app-controlled:

1. The app asks a planner model to derive a focused query.
2. The app runs note retrieval or Exa web search itself.
3. The app injects the results into the final prompt.
4. The chat model answers using the augmented prompt.

Relevant code:

- `CrossNoteSearchPlanner.makePlan(...)`
- `WebSearchPlanner.makePlan(...)`
- `ChatViewModel.sendCloudMessage(...)`
- `MultiNoteChatViewModel.sendCloudMessage(...)`

### Apple Foundation Models

Apple is the only provider with true in-session tool objects in normal chat:

- `NotesSearchTool`
- `ExaWebSearchTool`

Those are attached directly to `LanguageModelSession` in single-note and multi-note chat.

Relevant code:

- `ChatViewModel.appleFMTools(...)`
- `MultiNoteChatViewModel.appleFMTools(...)`

### Cloud Providers

Cloud providers do not get Apple-native `Tool` objects.

Instead, they use:

- explicit planner-first app-side retrieval/search
- implicit tool-decision helper calls for cross-note search and web search

Relevant code:

- `AIService.makeCrossNoteSearchToolDecision(...)`
- `AIService.makeWebSearchToolDecision(...)`

### Smart Search

Smart Search is separate from normal chat.

It always uses app-side RAG for note retrieval:

1. planner derives a better retrieval query
2. app runs local RAG search
3. app injects note evidence into the final prompt

Only Apple Foundation Models get an additional native web tool in Smart Search chat.

Relevant code:

- `SmartSearchQueryPlanner.makePlan(...)`
- `SmartSearchChatViewModel.sendCloudMessage(...)`
- `SmartSearchChatViewModel.appleFMTools`

## Provider Matrix

| Provider | Normal Chat | Cross-Note Search | Web Search | Implicit Tool Path in Normal Chat | Smart Search Notes RAG | Smart Search Web Tool | Notes |
|---|---|---|---|---|---|---|---|
| Apple | Yes | Yes | Yes | Yes - native Apple tools | Yes | Yes | Strongest support. Only provider with true in-session tools. |
| Anthropic API key | Yes | Yes | Yes | Yes | Yes | No | Uses dedicated Anthropic chat/tool-decision path. |
| OpenAI API key | Yes | Yes | Yes | Yes | Yes | No | Uses OpenAI-compatible chat path. |
| Gemini API key | Yes | Yes | Yes | Yes | Yes | No | Uses Gemini OpenAI-compatible chat endpoint for chat. |
| GitHub Copilot | Yes | Yes | Yes | Yes | Yes | No | Uses Copilot chat/completions path. |
| Groq | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| Mistral | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| Cerebras | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| Grok | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| Z.AI | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| Kimi | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| OpenRouter | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| Vercel AI Gateway | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| HuggingFace | Yes | Yes | Yes | Yes | Yes | No | Routed through shared OpenAI-compatible cloud path. |
| Ollama | Yes | Yes | Yes | Yes | Yes | No | Routed through local OpenAI-compatible chat path. |
| Custom OpenAI | Yes | Yes | Yes | Yes | Yes | No | Routed through custom OpenAI-compatible endpoint. |
| OpenAI OAuth only | Yes | Yes (planner) | Yes (planner) | No | Yes | No | Routed through Codex Responses backend. Implicit tool-calling deferred. |
| Gemini OAuth only | No | No | No | No | No | No | Chat is explicitly blocked today. |

## Providers Not Covered By Chat Tools

These providers exist in `AIProvider` but are not part of the current general chat provider set used by chat and RAG surfaces:

- ElevenLabs
- Deepgram
- Soniox
- Cohere

They should be treated as unsupported for chat tools unless chat routing is added for them separately.

## Important Nuances

### 1. "Supported" does not always mean native tool calling

For most cloud providers, support means:

- planner-first app-side retrieval/search works
- implicit tool-decision helpers can run

It does not mean the provider gets Apple-style runtime `Tool` objects.

### 2. Apple is special

Apple has the richest tool integration:

- normal chat can attach `NotesSearchTool`
- normal chat can attach `ExaWebSearchTool`
- Smart Search can attach `ExaWebSearchTool`

### 3. OAuth is different from API key support

OpenAI OAuth-only chat routes through the Codex Responses backend (`chatgpt.com/backend-api/codex/responses`) with a structured `input` body, not the standard Chat Completions `messages` body. Planner-based tool paths that call `makeChatRequest(...)` work because planners decode JSON from a plain text response. Implicit tool calling during normal chat (the `tools` + `tool_choice: "auto"` path) is not yet implemented for OAuth and is deferred.

Gemini OAuth-only chat is still blocked in the transport layer.

That means:

- OpenAI API key chat tools: supported
- OpenAI OAuth-only chat tools: planner-based tools supported, implicit chat tool-calling not yet supported
- Gemini API key chat tools: supported
- Gemini OAuth-only chat tools: not supported

## Key Source Files

- `VivaDicta/Services/AIEnhance/AIProvider.swift`
- `VivaDicta/Services/AIEnhance/AIService+Chat.swift`
- `VivaDicta/Services/AIEnhance/CrossNoteSearchPlanner.swift`
- `VivaDicta/Services/AIEnhance/WebSearchPlanner.swift`
- `VivaDicta/Services/AIEnhance/SmartSearchQueryPlanner.swift`
- `VivaDicta/Views/Chat/ChatViewModel.swift`
- `VivaDicta/Views/MultiNoteChat/MultiNoteChatViewModel.swift`
- `VivaDicta/Views/SmartSearch/SmartSearchChatViewModel.swift`
