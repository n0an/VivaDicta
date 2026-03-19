# Text Processing Pipeline

## Pipeline Overview

```
Audio Recording
    |
    v
Transcription Service (WhisperKit / Parakeet / Cloud)
    |
    v
TranscriptionOutputFilter.filter()              -- Stage 1: Clean raw transcription
    |
    v
TranscriptionOutputFilter.hasMeaningfulContent() -- Gate: discard empty/punctuation-only
    |
    v
TextFormatter.format()                           -- Stage 2: Paragraph formatting (if enabled)
    |
    v
ReplacementsService.applyReplacements()          -- Stage 3: User word replacements (if enabled)
    |
    v
[Transcribed text stored]
    |
    v
AIService.enhance() / generateVariation()        -- Stage 4: AI enhancement
    |  getSystemMessage()        -> system message
    |  formatTranscriptForLLM()  -> user message
    |
    v
AIEnhancementOutputFilter.filter()               -- Stage 5: Clean AI output
    |
    v
TextFormatter.format()                           -- Stage 5b: Paragraph formatting (Assistant preset only, if enabled)
    |
    v
[Enhanced text stored]
    |
    v  (Keyboard extension only)
TextInsertionFormatter.formatTextForInsertion()   -- Stage 6: Smart insertion formatting
    |
    v
[Text inserted into text field]
```

---

## Stage 1: TranscriptionOutputFilter

**File:** `Services/Transcription/TranscriptionOutputFilter.swift`

Cleans raw transcription output from any provider.

### `filter(_ text:) -> String`
1. Removes `<TAG>...</TAG>` blocks (full XML tag pairs with content)
2. Removes bracketed hallucinations: `[...]`, `(...)`, `{...}`
3. Removes filler words: "uh", "um", "uhm", "umm", "uhh", "uhhh", "ah", "eh", "hmm", "hm", "mmm", "mm", "mh", "ha", "ehh" (word-boundary regex, case-insensitive, including trailing comma/period)
4. Collapses multiple whitespace into single space
5. Trims leading/trailing whitespace

### `hasMeaningfulContent(_ text:) -> Bool`
Returns `true` if text contains at least one alphanumeric character. Rejects pure punctuation, whitespace, or empty strings.

**Called from:**
- `TranscriptionManager.transcribe()` -- immediately after receiving raw text
- `RecordViewModel` -- gates whether to save transcription

**Always active** -- not configurable.

---

## Stage 2: TextFormatter

**File:** `Services/Transcription/TextFormatter.swift`

Formats continuous transcription text into readable paragraphs using the `NaturalLanguage` framework (only place in the codebase using NL).

### `format(_ text:) -> String`
1. Detects dominant language via `NLLanguageRecognizer`
2. Tokenizes into sentences via `NLTokenizer(unit: .sentence)`
3. Counts words per sentence via `NLTokenizer(unit: .word)`
4. Groups sentences into paragraphs (~50 words or 4+ significant sentences per paragraph)
5. A "significant sentence" has 4+ words (short utterances like "Yes." don't count)
6. Joins paragraphs with `\n\n`

**Called from:**
- `TranscriptionManager.transcribe()` -- after `TranscriptionOutputFilter`
- `AIService.enhance()` -- after `AIEnhancementOutputFilter` (Assistant preset only)
- `AIService.generateVariation()` -- after `AIEnhancementOutputFilter` (Assistant preset only)

**Conditional:** Per-mode setting `VivaMode.isAutoTextFormattingEnabled` (default: `true` for existing modes, `false` for new modes).

---

## Stage 3: ReplacementsService

**File:** `Services/ReplacementsService.swift`

Applies user-defined find-and-replace rules from `WordReplacement` SwiftData model.

### `applyReplacements(to text:) -> String`
1. Fetches enabled `WordReplacement` records from SwiftData
2. Splits each `originalText` by comma for multiple variants
3. Detects script to decide word boundaries: `\b` for Latin/Cyrillic, none for CJK/Thai
4. Applies case-insensitive regex replacement

**Called from:** `TranscriptionManager.transcribe()`, after `TextFormatter`.

**Conditional:** Setting `isReplacementsEnabled` (default: `true`).

---

## Stage 4: AI Prompt Construction

### CustomVocabulary

**File:** `Utilities/CustomVocabulary.swift`

Not a filter per se, but part of the prompt pipeline. Retrieves user-defined vocabulary terms from `VocabularyWord` SwiftData model.

### `getTerms(maxTerms:) -> [String]`
Fetches terms, trims whitespace, deduplicates case-insensitively. Injected into:
- AI system messages as `<CUSTOM_VOCABULARY>` section
- Cloud transcription APIs (Groq prompt, Deepgram keywords, Soniox context terms)

**Conditional:** Setting `isSpellingCorrectionsEnabled` (default: `true`).

### PromptsTemplates.systemPrompt(with:)

**File:** `Services/AIEnhance/PromptsTemplates.swift`

Wraps preset `promptInstructions` inside the TRANSCRIPTION ENHANCER template:
- Role definition ("You are a TRANSCRIPTION ENHANCER, not a conversational AI Chatbot")
- 5 core rules (vocabulary usage, phonetic matching, output focus, Russian language, no em-dashes)
- User's preset instructions interpolated in the middle
- Final warning with 3 examples
- Used when `preset.useSystemTemplate == true`

When `useSystemTemplate == false` (e.g., Assistant preset), `promptInstructions` become the raw system message.

### AIService.formatTranscriptForLLM()

**File:** `Services/AIEnhance/AIService.swift`

Wraps transcript text in `<TRANSCRIPT>` tags when `preset.wrapInTranscriptTags == true`, or passes raw text when `false`.

---

## Stage 5: AIEnhancementOutputFilter

**File:** `Services/AIEnhance/AIEnhancementOutputFilter.swift`

Cleans AI model output before storing.

### `filter(_ text:) -> String`
1. **Remove thinking tags with content:** Strips `<thinking>...</thinking>`, `<think>...</think>`, `<reasoning>...</reasoning>` (chain-of-thought artifacts). Uses dotall mode for multiline.
2. **Unwrap outer XML tags:** If the entire output is wrapped in XML tags (e.g., `<TRANSCRIPTION>text</TRANSCRIPTION>`), iteratively unwraps keeping only inner content.

**Called from:** Every AI response path (Anthropic, OpenAI, Groq, Mistral, Ollama, Custom OpenAI, Apple Foundation Model).

**Always active** -- not configurable.

---

## Stage 6: TextInsertionFormatter (Keyboard Extension)

**File:** `VivaDictaKeyboard/TextInsertionFormatter.swift`

Smart formatting when inserting transcribed text from the keyboard extension.

### `formatTextForInsertion(_ text:, context:) -> String`

**Smart Spacing:**
- Adds space before text if cursor follows a letter, number, or punctuation
- Does NOT add space if cursor follows whitespace

**Smart Capitalization:**
- Capitalizes first letter after sentence-ending punctuation (`.!?`) or newline
- Lowercases first letter mid-sentence (unless all-caps acronym)

**Called from:** `KeyboardViewController.handleTranscription()`.

**Conditional:** Per-mode setting `VivaMode.isSmartInsertEnabled` (default: `true` for existing modes, `false` for new modes).

---

## Summary Table

| # | Component | Stage | Always Active | Setting |
|---|-----------|-------|---------------|---------|
| 1 | `TranscriptionOutputFilter.filter()` | After transcription | Yes | -- |
| 2 | `TranscriptionOutputFilter.hasMeaningfulContent()` | Gate check | Yes | -- |
| 3 | `TextFormatter.format()` | Paragraph formatting | No | `VivaMode.isAutoTextFormattingEnabled` |
| 4 | `ReplacementsService.applyReplacements()` | Word replacements | No | `isReplacementsEnabled` |
| 5 | `CustomVocabulary.getTerms()` | AI prompt injection | No | `isSpellingCorrectionsEnabled` |
| 6 | `PromptsTemplates.systemPrompt()` | AI system message | When `useSystemTemplate=true` | -- |
| 7 | `formatTranscriptForLLM()` | AI user message | When `wrapInTranscriptTags=true` | -- |
| 8 | `AIEnhancementOutputFilter.filter()` | After AI response | Yes | -- |
| 9 | `TextFormatter.format()` | After AI response (Assistant only) | No | `VivaMode.isAutoTextFormattingEnabled` |
| 10 | `TextInsertionFormatter` | Keyboard insertion | No | `VivaMode.isSmartInsertEnabled` |

### Server-Side Processing

Deepgram enables `smart_format`, `punctuate`, and `paragraphs` API parameters, performing server-side text formatting before the text enters the local pipeline.
