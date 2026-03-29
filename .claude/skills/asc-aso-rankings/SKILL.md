---
name: asc-aso-rankings
description: Pull current keyword rankings from Astro MCP, compare against a baseline snapshot, and save a new snapshot to the vault. Use to measure ASO impact after metadata changes.
argument-hint: [version to snapshot, e.g. "2.1.0"]
---

# ASO Rankings Snapshot & Comparison

Pull keyword rankings from Astro MCP, compare against the previous baseline snapshot, and save a new snapshot to the Obsidian vault.

## When to Use

- 2-4 weeks after a metadata update goes live
- Periodically to track ranking trends
- After a new version is approved and live on the App Store

## Prerequisites

- App tracked in Astro MCP (app ID: `6758147238`)
- Keywords tracked in Astro for the US store
- Previous snapshot exists in vault at `Projects/VivaDicta/ASO/`

## Steps

### 1. Pull Current Rankings

Call `mcp__astro__get_app_keywords` with appId `6758147238` to get all tracked keywords with current rankings, popularity, difficulty, and ranking changes.

### 2. Load Previous Snapshot

Read the most recent snapshot from the vault:
```
/Users/antonnovoselov/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain Vault/Projects/VivaDicta/ASO/
```

Look at the Snapshots table in `app-store-keywords.md` to find the latest snapshot file.

### 3. Compare Rankings

For each keyword, compare current rank vs. the baseline snapshot:

- **Improved**: rank went from #1000 → any number, or rank decreased (closer to #1)
- **Declined**: rank increased (further from #1), or dropped to #1000
- **New**: keyword wasn't in the previous snapshot
- **Stable**: rank unchanged or moved ≤ 5 positions

Calculate summary stats:
- Total keywords tracked
- Keywords ranked (not #1000) vs unranked
- Keywords improved / declined / stable / new
- Best rank achieved
- Biggest improvement (most positions gained)

### 4. Check Competitor Rankings

For the top 3 competitors (Otter, Wispr Flow, Whisper Transcription), call `mcp__astro__get_app_keywords` to get their current rankings for comparison.

Competitor app IDs:
- Otter: `1276437113`
- Wispr Flow: `6497229487`
- Whisper Transcription: `1668083311`

### 5. Save New Snapshot

Write a new snapshot file to the vault following the established format:

```
/Users/antonnovoselov/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain Vault/Projects/VivaDicta/ASO/aso-snapshot-{version}.md
```

**No frontmatter** — these are raw reference files (see obsidian skill exception for ASO files).

Snapshot format:
```markdown
# ASO Snapshot — VivaDicta v{version}

Date: YYYY-MM-DD

## Title & Subtitle

| Locale | Title | Subtitle |
...

## Keywords

### {locale} ({chars}/100)
...

## Rankings (US store)

| Keyword | Pop | Difficulty | Rank | Prev Rank | Change |
...

**Ranked: X/Y | Unranked: Z/Y**

## Cross-Field Combos
...

## Top Competitors (US store)
...
```

### 6. Update Tracker

Update `app-store-keywords.md` in the vault:
- Add the new snapshot to the Snapshots table
- If the version status was "in review" or "submitted", update to "live"

### 7. Present Comparison Report

Show a summary to the user:

```
### Rankings Comparison: v{old} → v{new}

**Overall:** X/Y ranked (was A/B) — {net change}
**Improved:** list of keywords that moved up
**Declined:** list of keywords that moved down
**New rankings:** keywords that entered top 250 for the first time
**Still unranked:** count of keywords at #1000

### Notable Changes
- Best performer: "{keyword}" at #{rank} (was #{prev})
- Biggest gain: "{keyword}" +{positions} positions

### vs Competitors
| Keyword | VivaDicta | Otter | Wispr | Whisper Trans. |
...
```

## Notes

- Rankings take time to update after metadata changes — wait at least 2 weeks
- Astro updates rankings daily; the snapshot captures a point-in-time view
- Keywords at #1000 mean unranked (not in top 250)
- Focus on keywords with popularity > 20 for meaningful impact assessment
