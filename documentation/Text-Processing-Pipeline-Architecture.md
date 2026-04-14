# Text Processing Pipeline Architecture

## Overview

VivaDicta applies a multi-stage text processing pipeline to transform raw audio transcriptions into clean, formatted text. The pipeline has two branches: one for transcription output and one for AI enhancement output, with shared stages.

## Full Pipeline Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Text Processing Pipeline                              │
│                                                                              │
│  Audio ──► Speech-to-Text Provider ──► Raw Transcription Text               │
│                                              │                               │
│                                              ▼                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  Stage 1: TranscriptionOutputFilter.filter()        [ALWAYS]        │   │
│  │                                                                      │   │
│  │  • Remove <TAG>...</TAG> XML blocks                                 │   │
│  │  • Remove bracketed hallucinations: [text], (text), {text}          │   │
│  │  • Remove filler words: uh, um, uhm, umm, hmm, ah, eh, etc.       │   │
│  │  • Collapse multiple spaces to single space                         │   │
│  │  • Trim whitespace                                                  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                              │                               │
│                                              ▼                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  Stage 2: TextFormatter.format()         [IF mode.isAutoTextFormat] │   │
│  │                                                                      │   │
│  │  Split continuous text into readable paragraphs:                    │   │
│  │  • Target: ~50 words per paragraph                                  │   │
│  │  • Max: 4 significant sentences (4+ words) per paragraph           │   │
│  │  • Short utterances ("Yes.", "OK.") don't count as significant     │   │
│  │  • Uses NaturalLanguage framework with auto language detection     │   │
│  │  • Output: paragraphs joined by \n\n                               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                              │                               │
│                                              ▼                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  Stage 3: ReplacementsService.applyReplacements()  [IF enabled]     │   │
│  │                                                                      │   │
│  │  SwiftData-backed word/phrase replacements:                         │   │
│  │  • Comma-separated originals → single replacement                  │   │
│  │  • Case-insensitive regex matching                                 │   │
│  │  • Word-boundary aware (\b) for Latin/Cyrillic scripts             │   │
│  │  • No word boundaries for CJK, Hangul, Thai scripts                │   │
│  │  • Only enabled replacements applied                                │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                              │                               │
│                                              ▼                               │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  Gate: TranscriptionOutputFilter.hasMeaningfulContent() [ALWAYS]    │   │
│  │                                                                      │   │
│  │  • Runs after filter, formatting, and replacements                  │   │
│  │  • Rejects empty / whitespace-only / punctuation-only text          │   │
│  │  • Used before saving the transcription                             │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                              │                               │
│                            ┌─────────────────┴─────────────────┐            │
│                            │                                    │            │
│                   AI Processing enabled?                        │            │
│                     YES                              NO         │            │
│                      │                                │         │            │
│                      ▼                                ▼         │            │
│  ┌──────────────────────────────┐    ┌────────────────────┐    │            │
│  │  Stage 4: AIService.enhance()│    │  Final output      │    │            │
│  │                              │    │  (text only)       │    │            │
│  │  Send to AI provider with:  │    └────────────────────┘    │            │
│  │  • System prompt (preset)   │                               │            │
│  │  • Custom vocabulary        │                               │            │
│  │  • Clipboard context        │                               │            │
│  │  • Transcript text          │                               │            │
│  └──────────────┬───────────────┘                               │            │
│                  │                                               │            │
│                  ▼                                               │            │
│  ┌──────────────────────────────┐                               │            │
│  │  Stage 5: AIEnhancement     │                               │            │
│  │  OutputFilter.filter()      │                               │            │
│  │                              │                               │            │
│  │  • Remove <thinking> blocks │                               │            │
│  │  • Remove <think> blocks    │                               │            │
│  │  • Remove <reasoning> blocks│                               │            │
│  │  • Unwrap outer XML tags    │                               │            │
│  │    iteratively              │                               │            │
│  └──────────────┬───────────────┘                               │            │
│                  │                                               │            │
│                  ▼                                               │            │
│  ┌──────────────────────────────┐                               │            │
│  │  Stage 6: TextFormatter     │                               │            │
│  │  (assistant preset only,    │                               │            │
│  │   if autoFormatting enabled)│                               │            │
│  └──────────────┬───────────────┘                               │            │
│                  │                                               │            │
│                  ▼                                               │            │
│           Final output                                          │            │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  Stage 7: TextInsertionFormatter   [KEYBOARD EXTENSION ONLY]        │   │
│  │                                                                      │   │
│  │  Context-aware formatting when inserting text via keyboard:         │   │
│  │  • Smart spacing (add space before if needed)                       │   │
│  │  • Auto-capitalization after sentence endings                       │   │
│  │  • Contraction handling                                             │   │
│  │  • Enabled per-mode via isSmartInsertEnabled                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Stage Details

### Stage 1: TranscriptionOutputFilter

Removes common speech-to-text artifacts. Applied unconditionally to all transcriptions.

**Hallucination Patterns Removed:**
- `[any text in brackets]` — model hallucinations like `[Music]`, `[BLANK_AUDIO]`
- `(any text in parens)` — annotations like `(laughs)`, `(inaudible)`
- `{any text in braces}` — rare but possible artifacts

**XML Tag Blocks Removed:**
- `<TAG>content</TAG>` — removes full tag blocks (self-referencing regex `<(\w+)>...<\/\1>`)

**Filler Words Removed (word-boundary matched, case-insensitive):**
`uh`, `um`, `uhm`, `umm`, `uhh`, `uhhh`, `ah`, `eh`, `hmm`, `hm`, `mmm`, `mm`, `mh`, `ha`, `ehh`

Also removes trailing comma/period after filler words.

**Meaningful Content Check:**
`hasMeaningfulContent(_:)` returns `false` for strings that are empty, whitespace-only, or contain only punctuation. In the current code path, this gate runs after Stage 1, optional Stage 2, and optional Stage 3, and is used to skip saving empty transcriptions.

### Stage 2: TextFormatter

Splits continuous text into readable paragraphs using NaturalLanguage framework.

**Algorithm:**

```
Input: continuous text
    │
    ├── Detect dominant language (NLLanguageRecognizer)
    ├── Tokenize into sentences (NLTokenizer, .sentence)
    ├── Pre-compute word counts for all sentences (NLTokenizer, .word)
    │
    ├── Build chunks:
    │   for each sentence:
    │     accumulate into current chunk
    │     if wordCount >= 4 → count as significant sentence
    │     if total words >= 50 → finalize chunk
    │
    ├── Trim if needed:
    │   if significant sentences > 4:
    │     cut chunk at 4th significant sentence
    │     (short utterances included but don't count)
    │
    └── Join chunks with "\n\n"
```

**Configuration:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `targetWordCount` | 50 | Words per paragraph target |
| `maxSentencesPerChunk` | 4 | Max significant sentences per paragraph |
| `minWordsForSignificantSentence` | 4 | Threshold for counting a sentence |

**Example:**
```
Input:  "Hello. Yes. This is a longer sentence. Another point. I agree. Third idea. Fourth statement."
         ^short  ^short  ^significant(1)    ^signif(2)   ^short  ^signif(3)  ^signif(4) → split

Output: "Hello. Yes. This is a longer sentence. Another point.\n\nI agree. Third idea. Fourth statement."
```

### Stage 3: ReplacementsService

SwiftData-backed word replacement engine.

**Data Model:** `WordReplacement` (SwiftData, CloudKit-synced)
- `originalText`: comma-separated variants (e.g., "colour, colour's")
- `replacementText`: target text (e.g., "color")
- `isEnabled`: toggle per replacement

**Matching Strategy:**
```
For each enabled replacement:
  Split originalText by comma → variants
  For each variant:
    if usesWordBoundaries(variant):
      regex: \b{escaped_variant}\b  (case-insensitive)
    else (CJK/Thai):
      regex: {escaped_variant}  (no boundaries, case-insensitive)
```

**Word Boundary Detection:**
Checks if text contains characters from non-spaced scripts:
- Hiragana (U+3040–U+309F)
- Katakana (U+30A0–U+30FF)
- CJK Unified Ideographs (U+4E00–U+9FFF)
- Hangul Syllables (U+AC00–U+D7AF)
- Thai (U+0E00–U+0E7F)

If any character is in these ranges → no word boundaries used.

### Stage 5: AIEnhancementOutputFilter

Removes AI-generated artifacts from enhancement output.

**Step 1: Remove thinking blocks WITH content:**
- `<thinking>...</thinking>`
- `<think>...</think>`
- `<reasoning>...</reasoning>`

These are AI chain-of-thought blocks that should never appear in output.

**Step 2: Unwrap outer XML tags (keep content):**
Iteratively removes XML tags that wrap the ENTIRE response:
```
<result><transcription>Hello world</transcription></result>
→ <transcription>Hello world</transcription>
→ Hello world
```

Pattern: `^<tag>content</tag>$` with backreference matching.

### Stage 7: TextInsertionFormatter (Keyboard Only)

Applied when inserting transcribed text via the keyboard extension. Not part of the main pipeline — runs in `KeyboardDictationState`.

- Analyzes text before cursor for context
- Adds space before inserted text if needed
- Capitalizes first letter after sentence-ending punctuation
- Handles contractions and special punctuation
- Controlled by `VivaMode.isSmartInsertEnabled`

## Pipeline Toggles

| Stage | Toggle | Default |
|-------|--------|---------|
| TranscriptionOutputFilter | Always on | — |
| TextFormatter | `VivaMode.isAutoTextFormattingEnabled` | `true` |
| ReplacementsService | `UserDefaults.isReplacementsEnabled` | `true` |
| AI Processing | `VivaMode.aiEnhanceEnabled` + properly configured | `false` |
| AI Output Filter | Always on (when AI used) | — |
| Smart Insertion | `VivaMode.isSmartInsertEnabled` | `true` |

## Custom Vocabulary Integration

Custom vocabulary words (`VocabularyWord` SwiftData model, CloudKit-synced) are injected into the AI system prompt as context:

```
<CUSTOM_VOCABULARY>Important Vocabulary: term1, term2, term3
</CUSTOM_VOCABULARY>
```

This helps the AI correct transcription errors where phonetically similar words were misrecognized. The system prompt instructs the AI to prioritize vocabulary terms over transcript text when phonetic matches are detected.
