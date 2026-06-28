---
name: krankie-rankings
description: Pull VivaDicta App Store keyword rankings via krankie (free, self-hosted), compare against the previous check, and write a dated rankings report to the Obsidian vault. Krankie-based replacement for asc-aso-rankings (no Astro subscription required).
argument-hint: [optional notes, e.g. "2 week check"]
---

# ASO Rankings Check (krankie)

Pull keyword rankings with **krankie** instead of Astro MCP, compare against the previous check, and save a dated rankings file to the Obsidian vault.

This is the no-subscription replacement for `asc-aso-rankings`. krankie is MIT-licensed, stores history in local SQLite, and reads ranks from the public App Store search API. The trade-off vs Astro: **krankie reports rank position only - no popularity or difficulty scores**, and tracks the top 200 (Astro tracked top 250).

## Architecture: VPS is the source of truth

- **VPS (`lobster@openclawtail`)** runs krankie under a **daily cron** (`krankie cron`), so the SQLite DB there holds the continuous day-over-day history. This is canonical.
- **MacBook** also has krankie installed for ad-hoc local peeks, but its DB only has data from whenever it was last run - do **not** use it for the historical comparison.
- The vault is **bidirectionally synced** between the VPS (`/home/lobster/vault`) and the MacBook (`/Users/antonnovoselov/Documents/Vault`), so a report written on either side appears on both.

Because the VPS holds the history and the `previous_rank`/`rank_change` columns krankie computes between checks, **run the check + report on the VPS**.

## Tracked set (the documented strategy)

Track the **41 canonical keywords** from the ASO strategy (see `app-store-keywords.md` change log) plus the brand term `vivadicta`, for the app `6758147238`, on stores **us, gb, ca, au**. The same 41 keywords are tracked for 3 competitors on **us** only:

- Otter `1276437113`
- Wispr Flow `6497229487`
- Whisper Transcription `1668083311`

The keyword list and competitor set live in `~/.krankie/` setup on the VPS; the report generator is `~/.krankie/kr_report.mjs`.

## Steps

### 1. Run a fresh check + generate the report (VPS)

```bash
ssh lobster@openclawtail 'export PATH="$HOME/.bun/bin:$PATH"; \
  krankie check run --force >/dev/null 2>&1; \
  REPORT_VERSION="<live-version>" bun ~/.krankie/kr_report.mjs'
```

- `krankie check run --force` re-checks every tracked keyword now (ignores the 24h throttle).
- `kr_report.mjs` reads `krankie rankings --json`, writes `rankings/rankings-YYYY-MM-DD.md` to the vault, and appends a row to the `app-store-keywords.md` index. Pass `REPORT_VERSION` to stamp the live metadata version (default `3.7.0`).
- The generator prints the output path and a one-line summary.

### 2. Read the produced report

The file syncs to the MacBook at:

```
/Users/antonnovoselov/Documents/Vault/Projects/VivaDicta/ASO/rankings/rankings-YYYY-MM-DD.md
```

If sync lag is a problem, `scp` it back: `scp lobster@openclawtail:/home/lobster/vault/Projects/VivaDicta/ASO/rankings/rankings-YYYY-MM-DD.md /tmp/`.

### 3. Compare against the previous check

The report's `Change` column already reflects krankie's `previous_rank` (the prior check, i.e. yesterday under cron). For a longer-horizon comparison, read the previous dated `rankings-*.md` and diff:

- **Improved**: rank moved closer to #1 (or entered top 200 = `NEW`)
- **Declined**: rank moved away from #1 (or fell out of top 200 = `DROPPED`)
- **Stable**: unchanged or +/- a few positions

### 4. Present the comparison report

```
### Rankings Check: YYYY-MM-DD (krankie) (vs previous: YYYY-MM-DD)

**Overall:** X/41 ranked (was A/41)
**Improved:** keywords that moved up
**Declined:** keywords that moved down
**New rankings:** keywords that entered top 200
**Best performer:** "{keyword}" at #{rank}
**Biggest gain:** "{keyword}" +{positions}

### vs Competitors (US)
| Keyword | VivaDicta | Otter | Wispr Flow | Whisper Trans. |
...

### Gap opportunities (competitors rank, we don't)
- keywords where a competitor is top-50 and VivaDicta is unranked
```

## Report format

`kr_report.mjs` emits three sections:

1. **VivaDicta Rankings (US store)** - `| Keyword | Rank | Prev | Change |`, sorted ranked-first then unranked by best-competitor-rank (gap priority).
2. **Competitors (US store)** - `| Keyword | VivaDicta | Otter | Wispr Flow | Whisper Trans. |`.
3. **International reach** - VivaDicta US/GB/CA/AU for any keyword ranked in any store.

No frontmatter (raw reference file), matching the existing `rankings-*.md` convention.

## Fallback: MacBook-local (VPS unreachable / Tailscale down)

krankie is also installed on the MacBook (`~/.bun/bin/krankie`). You can run an ad-hoc check locally, but it lacks the VPS's day-over-day history, so `Change` will be empty/`NEW`:

```bash
krankie check run --force
krankie rankings --json
```

Then hand-build the report in the April format.

## Notes

- Rankings take 1-2 weeks to settle after a metadata change.
- krankie ranks 1-200; blank = not in top 200. Lower is better.
- Recommended cadence: the VPS cron checks daily; generate a vault report weekly, or on demand right after a metadata change.
- No popularity/difficulty - prioritize gaps by **competitor rank** (a keyword Otter/Wispr win and we don't) instead of by Astro popularity.
- Related: `krankie-audit` (offline metadata checks + competitor rank-gap analysis).
