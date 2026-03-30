---
name: asc-aso-rankings
description: Pull current keyword rankings from Astro MCP, compare against the previous rankings check, and save a new rankings file to the vault. Use to measure ASO impact after metadata changes.
argument-hint: [optional notes, e.g. "2 week check"]
---

# ASO Rankings Check

Pull keyword rankings from Astro MCP, compare against the previous check, and save a new rankings file to the Obsidian vault.

## Vault Structure

```
Projects/VivaDicta/ASO/
  app-store-keywords.md       — index (changelog, links, reference)
  metadata-{version}.md       — titles/subtitles/keywords per release (one per version)
  rankings/
    rankings-YYYY-MM-DD.md    — rankings check per date (many per version)
```

- **Metadata files** are tied to a release version and date. Only created when a new version ships.
- **Rankings files** are dated point-in-time checks. Can be created anytime (weekly, bi-weekly, etc.)

Vault path:
```
/Users/antonnovoselov/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain Vault/Projects/VivaDicta/ASO/
```

## Steps

### 1. Load Previous Rankings

Read `app-store-keywords.md` to find the latest rankings check in the "Rankings Checks" table. Read that file to get the previous rankings for comparison.

### 2. Pull Current Rankings

Call `mcp__astro__get_app_keywords` with appId `6758147238` to get all tracked keywords with current rankings, popularity, difficulty, and ranking changes.

### 3. Compare Rankings

For each keyword, compare current rank vs. the previous check:

- **Improved**: rank decreased (closer to #1), or entered top 250 from #1000
- **Declined**: rank increased (further from #1), or dropped to #1000
- **New kw**: keyword wasn't tracked in the previous check
- **Stable**: rank unchanged or moved ≤ 5 positions

Calculate summary stats:
- Total keywords tracked
- Keywords ranked (not #1000) vs unranked
- Keywords improved / declined / stable / new
- Best rank achieved
- Biggest improvement (most positions gained)

### 4. Check Competitor Rankings

For the top 3 competitors, call `mcp__astro__get_app_keywords`:

- Otter: `1276437113`
- Wispr Flow: `6497229487`
- Whisper Transcription: `1668083311`

### 5. Save Rankings File

Write to:
```
rankings/rankings-YYYY-MM-DD.md
```

**No frontmatter** — raw reference files.

Format:
```markdown
# Rankings — YYYY-MM-DD

Live metadata: v{version} ({n} locales)
Keywords tracked: {n}

## VivaDicta Rankings (US store)

| Keyword | Pop | Difficulty | Rank | Prev Check | Change |
|---------|-----|-----------|------|------------|--------|
...

**Ranked: X/Y | Unranked: Z/Y**

## Competitors (US store)

| Keyword | Pop | VivaDicta | Otter | Wispr Flow | Whisper Trans. |
|---------|-----|-----------|-------|------------|----------------|
...
```

Sort keywords by: ranked first (ascending by rank), then unranked sorted by popularity descending.

### 6. Update Index

In `app-store-keywords.md`, add a new row to the "Rankings Checks" table:

```
| YYYY-MM-DD | v{version} | {ranked}/{total} | [rankings-YYYY-MM-DD.md](rankings/rankings-YYYY-MM-DD.md) |
```

### 7. Present Comparison Report

Show a summary to the user:

```
### Rankings Check: YYYY-MM-DD (vs previous: YYYY-MM-DD)

**Overall:** X/Y ranked (was A/B)
**Improved:** list of keywords that moved up
**Declined:** list of keywords that moved down
**New rankings:** keywords that entered top 250 for the first time
**Still unranked:** count of keywords at #1000

### Notable
- Best performer: "{keyword}" at #{rank}
- Biggest gain: "{keyword}" +{positions} positions

### vs Competitors
| Keyword | VivaDicta | Otter | Wispr | Whisper Trans. |
...
```

## Notes

- Rankings take 1-2 weeks to settle after metadata changes
- Astro updates rankings daily; each check is a point-in-time snapshot
- Keywords at #1000 mean unranked (not in top 250)
- Focus on keywords with popularity > 20 for meaningful impact assessment
- Recommended cadence: bi-weekly, or weekly right after a metadata change
