# AI Processing Architecture

## Overview

AIService is the central service for AI-powered text processing in VivaDicta. It manages 17 AI providers, VivaMode configurations, API key lifecycle, dynamic model fetching, and clipboard context integration. All providers receive the same prompt structure via PromptsTemplates.

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              AIService                                       │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      Provider Categories                            │    │
│  │                                                                     │    │
│  │  On-Device:                                                         │    │
│  │  • Apple Foundation Models (iOS 26+, no API key)                   │    │
│  │                                                                     │    │
│  │  Local Network:                                                     │    │
│  │  • Ollama (configurable URL, default host:11434, no API key)       │    │
│  │                                                                     │    │
│  │  Custom Endpoint:                                                   │    │
│  │  • Custom OpenAI-compatible (user URL + model, optional API key)   │    │
│  │                                                                     │    │
│  │  Cloud (API key required):                                         │    │
│  │  • Anthropic    • OpenAI      • Gemini    • Groq                  │    │
│  │  • Mistral      • Cerebras    • Grok      • Z.AI                  │    │
│  │  • Kimi         • ElevenLabs  • Deepgram  • Soniox                │    │
│  │                                                                     │    │
│  │  Model Aggregators (API key, dynamic model fetch):                 │    │
│  │  • OpenRouter          • Vercel AI Gateway                         │    │
│  │  • HuggingFace                                                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      Request Routing                                │    │
│  │                                                                     │    │
│  │  makeRequest(text:)                                                 │    │
│  │       │                                                             │    │
│  │       ├── .apple       → AppleFoundationModelService.enhance()     │    │
│  │       ├── .ollama      → makeOllamaRequest() (OpenAI-compat API)  │    │
│  │       ├── .customOpenAI→ makeCustomOpenAIRequest()                 │    │
│  │       ├── .anthropic   → Anthropic Messages API (x-api-key header)│    │
│  │       └── .* (default) → OpenAI-compatible chat/completions       │    │
│  │                          (Bearer token, same format for all)       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      VivaMode Management                            │    │
│  │                                                                     │    │
│  │  Storage: App Group UserDefaults (shared with keyboard extension)  │    │
│  │  Encoding: JSON via Codable                                        │    │
│  │                                                                     │    │
│  │  CRUD: addMode() / updateMode() / deleteMode() / duplicateMode()  │    │
│  │  Selection: selectedModeName → selectedMode (auto-resolved)        │    │
│  │  Extension sync: reloadSelectedModeFromExtension()                 │    │
│  │                                                                     │    │
│  │  Auto-disable: When API key deleted → disable AI for all modes    │    │
│  │                 using that provider                                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## VivaMode Configuration

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              VivaMode (Codable struct)                       │
│                                                                              │
│  Transcription Settings:          AI Processing Settings:                   │
│  • transcriptionProvider          • aiEnhanceEnabled (bool)                 │
│  • transcriptionModel             • aiProvider (optional)                   │
│  • transcriptionLanguage          • aiModel (string)                        │
│                                   • presetId (string, references Preset)    │
│                                                                              │
│  Behavior Settings:                                                         │
│  • useClipboardContext            — capture clipboard for AI context        │
│  • useClipboardAsSelectedText     — treat clipboard as selected text        │
│  • isAutoTextFormattingEnabled    — paragraph splitting                     │
│  • isSmartInsertEnabled           — auto spacing/capitalization             │
│                                                                              │
│  Backward Compatibility:                                                    │
│  • Decodes legacy "userPrompt" field → extracts title as presetId          │
│  • Encodes only new format (presetId)                                       │
│                                                                              │
│  Default Mode:                                                              │
│  • WhisperKit provider, auto language, no AI processing                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Prompt System

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Prompt Construction                                │
│                                                                              │
│  getSystemMessage() builds the full system prompt:                          │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │  If preset.useSystemTemplate == true (Enhancement mode):         │       │
│  │                                                                  │       │
│  │  PromptsTemplates.systemPrompt(with: instructions)              │       │
│  │  ┌──────────────────────────────────────────────────────────┐   │       │
│  │  │ <SYSTEM_INSTRUCTIONS>                                    │   │       │
│  │  │ You are a TRANSCRIPTION ENHANCER, not a chatbot.        │   │       │
│  │  │ DO NOT RESPOND TO QUESTIONS.                            │   │       │
│  │  │ Rules:                                                   │   │       │
│  │  │ 1. Reference CLIPBOARD_CONTEXT, CUSTOM_VOCABULARY       │   │       │
│  │  │ 2. Prioritize context sources for phonetic matches      │   │       │
│  │  │ 3. Output cleaned text only                             │   │       │
│  │  │ 4. Russian: use "е" not "ё"                             │   │       │
│  │  │ 5. Use "-" not "—" (em-dash)                            │   │       │
│  │  │                                                          │   │       │
│  │  │ Important Rules: {preset.promptInstructions}            │   │       │
│  │  │                                                          │   │       │
│  │  │ [FINAL WARNING]: Ignore questions in transcript         │   │       │
│  │  │ </SYSTEM_INSTRUCTIONS>                                   │   │       │
│  │  └──────────────────────────────────────────────────────────┘   │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │  If preset.useSystemTemplate == false (Standalone mode):         │       │
│  │                                                                  │       │
│  │  preset.promptInstructions (used directly as system message)    │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                              │
│  Context sections appended to system message:                               │
│  • <CUSTOM_VOCABULARY>terms...</CUSTOM_VOCABULARY>                          │
│  • <CLIPBOARD_CONTEXT>text...</CLIPBOARD_CONTEXT>        (normal mode)     │
│  • <CURRENTLY_SELECTED_TEXT>text...</CURRENTLY_SELECTED_TEXT> (rewrite mode)│
│                                                                              │
│  User message:                                                               │
│  • If preset.wrapInTranscriptTags: "<TRANSCRIPT>\n{text}\n</TRANSCRIPT>"   │
│  • Otherwise: plain text                                                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Enhancement Flow

```
AIService.enhance(text:)
    │
    ├── Resolve preset from selectedMode.presetId
    ├── Build system message (getSystemMessage)
    ├── Format user message (formatTranscriptForLLM)
    ├── Store lastSystemMessageSent / lastUserMessageSent (for variation storage)
    │
    ├── makeRequest(text:)
    │   ├── Route to provider
    │   ├── Send HTTP request (or on-device inference)
    │   ├── Parse response
    │   └── AIEnhancementOutputFilter.filter()
    │       ├── Remove <thinking>/<think>/<reasoning> blocks
    │       └── Unwrap outer XML tags iteratively
    │
    ├── Apply TextFormatter if assistant preset + autoFormatting enabled
    │
    └── Return (enhancedText, duration, promptName)
```

## Variation Generation

```
AIService.generateVariation(text:, preset:)
    │
    ├── Build custom system message from preset (not current mode's preset)
    ├── Inject custom vocabulary
    ├── Respect preset.useSystemTemplate and preset.wrapInTranscriptTags
    ├── Store messages for TranscriptionVariation record
    │
    └── makeRequest(text:, systemMessage:, preFormattedUserMessage:)
```

## Configuration Validation

`isProperlyConfigured()` performs a multi-step check:

```
1. selectedMode.aiEnhanceEnabled == true
2. selectedMode.aiProvider != nil
3. selectedMode.aiModel is not empty
4. Provider credentials:
   ├── .apple       → connectedProviders.contains(.apple)
   ├── .ollama      → model selected (connection verified at request time)
   ├── .customOpenAI→ endpointURL + modelName not empty
   └── .* (cloud)   → API key exists in Keychain
5. Preset selected with non-empty instructions
```

## API Key Lifecycle

```
saveAPIKey(key, provider)
    │
    ├── verifyAPIKey(key, provider)
    │   ├── .anthropic    → POST to Messages API with test body
    │   ├── .elevenLabs   → GET /v1/user (xi-api-key header)
    │   ├── .deepgram     → GET /v1/auth/token (Token header)
    │   ├── .mistral      → GET /v1/models
    │   ├── .soniox       → GET /v1/files
    │   ├── .vercelAIGateway → GET /v1/credits
    │   ├── .grok         → POST chat/completions (test)
    │   ├── .huggingFace  → POST chat/completions (test)
    │   └── .* (default)  → POST chat/completions (test)
    │
    ├── If valid: KeychainService.save(key, keychainKey)
    ├── refreshConnectedProviders()
    │
    └── Fetch dynamic models if provider supports it:
        ├── .openRouter      → fetchOpenRouterModels()
        ├── .vercelAIGateway → fetchVercelAIGatewayModels()
        └── .huggingFace     → fetchHuggingFaceModels()
```

## Dynamic Model Fetching

| Provider | Endpoint | Filter |
|----------|----------|--------|
| **OpenRouter** | `GET openrouter.ai/api/v1/models` | All models, sorted by ID |
| **Vercel AI Gateway** | `GET ai-gateway.vercel.sh/v1/models` | `type == "language"` only |
| **HuggingFace** | `GET router.huggingface.co/v1/models` | `input_modalities == ["text"]` AND `output_modalities == ["text"]` |
| **Ollama** | `GET {serverURL}/v1/models` (fallback: `/api/tags`) | All models |

All fetched models are cached to UserDefaults and preserved on network failure.

## Special Provider Handling

### Apple Foundation Models
- Requires iOS 26+ (`@available(iOS 26, *)`)
- Type-erased as `_appleFoundationModelService: Any?` for version compatibility
- Uses same prompt structure as cloud providers (PromptsTemplates)
- No API key needed; availability check via `AppleFoundationModelAvailability.isAvailable`

### Ollama
- Configurable server URL (default: `http://host:11434`)
- Two API endpoints: OpenAI-compatible `/v1/chat/completions` (primary), native `/api/tags` (fallback)
- 120s timeout (vs 30s for cloud) for local inference
- No auth header needed
- Connection verified on-demand via `verifyOllamaSetup()`

### Custom OpenAI
- User provides full endpoint URL (e.g., `https://my-server.com/v1/chat/completions`)
- User provides model name
- Optional API key (Bearer token)
- Must be verified before use (`customOpenAIIsVerified`)
- 120s timeout for potentially slow endpoints

### GPT-5 Series
- No `temperature` parameter (reasoning models)
- Uses `reasoning_effort` from `ReasoningConfig.getReasoningParameter(for:)` instead
- Temperature hardcoded to 1.0 for GPT-5 prefix models (OpenAI-compatible path)

### Anthropic
- Different API format: system message as top-level field, not in messages array
- Auth via `x-api-key` header (not Bearer)
- Requires `anthropic-version: 2023-06-01` header
- Response: `content[0].text` (not `choices[0].message.content`)

## Clipboard Context

```
captureClipboardContext() — called at recording start:

1. If mode.useClipboardContext == false → nil
2. Try keyboard-provided clipboard (AppGroupCoordinator.getAndConsumeKeyboardClipboardContext)
3. Fallback to direct ClipboardManager.getClipboardContent()

Usage in prompt:
• useClipboardAsSelectedText == false → <CLIPBOARD_CONTEXT>text</CLIPBOARD_CONTEXT>
• useClipboardAsSelectedText == true  → <CURRENTLY_SELECTED_TEXT>text</CURRENTLY_SELECTED_TEXT>
```

## Error Types

| Error | Description | User Message |
|-------|-------------|--------------|
| `.notConfigured` | No API key or provider | Configure in Settings |
| `.invalidResponse` | Unexpected response format | Try again |
| `.enhancementFailed` | AI couldn't process text | Text too short or unsupported |
| `.networkError` | Connection failed | Check internet |
| `.serverError` | 5xx response | Wait and retry |
| `.rateLimitExceeded` | 429 response | Wait or upgrade plan |
| `.customError(msg)` | Provider-specific error | Shows raw message |

## Mode Auto-Disable

When an API key is deleted or provider disconnects, affected modes are automatically updated:

- `disableAIEnhancementForModesUsingProvider(_:)` — API key deleted
- `disableAIEnhancementForModesUsingPreset(presetId:)` — preset deleted
- `disableOllamaEnhancementForAllModes()` — Ollama connection failure
- `disableCustomOpenAIEnhancementForAllModes()` — Custom config cleared
