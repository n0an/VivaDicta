# Sayboard Preflight And Comparison Notes

Repository inspected: `/Users/antonnovoselov/Desktop/sayboard`
Comparison target: `/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/VivaDicta`

## Hotspots

Command:

```bash
git -C /Users/antonnovoselov/Desktop/sayboard log --format=format: --name-only --since='1 year ago' | sort | uniq -c | sort -nr | head -20
```

Interpretation:
- This signal is almost useless here because the public repository has only one commit.
- Every path appears with count `1`, so churn does not distinguish risky or central files.

Command:

```bash
git -C /Users/antonnovoselov/Desktop/sayboard log --since='1 year ago' --dirstat=files,10,cumulative
```

Interpretation:
- The code mass is concentrated in `Sayboard/Resources/`, `Sayboard/Services/`, `Sayboard/Views/`, and `SayboardKeyboard/`.
- The best code-reading targets are therefore the service layer plus the keyboard extension, not git hotspots.

## Ownership

Command:

```bash
git -C /Users/antonnovoselov/Desktop/sayboard shortlog -sn --no-merges
```

Interpretation:
- No meaningful ownership signal surfaced because the repository history is a single release commit.
- Confidence is low for any authorship or bus-factor conclusion.

## Change Shape

Command:

```bash
git -C /Users/antonnovoselov/Desktop/sayboard rev-list --count HEAD
git -C /Users/antonnovoselov/Desktop/sayboard log --oneline --decorate --stat
```

Interpretation:
- The repo contains exactly `1` commit tagged `v1.0.0`.
- README confirms the source code is published per public release, one commit per release.
- Treat this as a source snapshot, not as an actively collaborative engineering history.

## Momentum

Command:

```bash
git -C /Users/antonnovoselov/Desktop/sayboard log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
```

Interpretation:
- Only `2026-03` appears.
- There is no trend data to infer delivery rhythm, staffing, or stability over time.

## Firefighting

Command:

```bash
git -C /Users/antonnovoselov/Desktop/sayboard log --oneline --since='1 year ago' | rg -i 'revert|hotfix|emergency|rollback'
```

Interpretation:
- No results.
- Confidence is low because the repository history is too shallow for this signal.

## Next Reads

Best code-reading targets from this snapshot:

1. `Shared/SharedSettings.swift`, `Shared/TranscriptionBridge.swift`, `Shared/LLMBridge.swift`
2. `Sayboard/Services/SpeechRecognitionService.swift`
3. `Sayboard/Services/LLMProcessingCoordinator.swift`
4. `SayboardKeyboard/KeyboardViewController.swift`
5. `Sayboard/Services/PiPTutorialService.swift`

## Comparison Leads

High-value ideas worth independent reimplementation:

1. Per-host writing style overrides in the keyboard flow.
2. Snippet expansion applied after transcription cleanup and before insertion.
3. PiP tutorial overlays for keyboard/full-access setup.
4. Lightweight background model-download UX for fully local speech and LLM models.
5. Keyboard-side LLM undo/redo history for repeated rewrite actions.

Areas VivaDicta already handles better:

1. Much richer AI pipeline and provider support.
2. Stronger preset architecture with built-in plus custom presets.
3. Better data model with persistent transcriptions, variations, Spotlight, and App Intents.
4. More advanced keyboard-to-app architecture and host return flow.

Important constraint:

- Sayboard is GPLv3. Product ideas are fair game, but copying implementation details into VivaDicta would create licensing risk unless VivaDicta is made GPL-compatible.
