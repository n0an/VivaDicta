---
name: krankie-audit
description: Run an ASO audit on canonical App Store metadata under `./metadata`, then a krankie-based competitor keyword-gap analysis (no Astro subscription). Krankie replacement for asc-aso-audit. Use after `asc metadata pull`.
---

# ASO Audit (krankie)

Two-phase ASO audit. **Phase 1 (offline metadata checks)** is identical to `asc-aso-audit` and needs no network. **Phase 2** replaces Astro's popularity/competitor analysis with **krankie** competitor rank-gap analysis.

What changes vs the Astro version: krankie gives **rank position only** - there is no popularity score, no difficulty score, and no keyword-suggestion engine. So Phase 2 finds gaps by **competitor rank** (keywords a competitor ranks well for that VivaDicta does not), not by popularity.

## Preconditions

- Metadata pulled into canonical files: `asc metadata pull --app "6758147238" --version "X.Y.Z" --dir "./metadata"`.
- For Phase 2: krankie tracking the app + competitors (the VPS at `lobster@openclawtail` is already set up; see `krankie-rankings`).

## Phase 1: Offline Checks (unchanged)

Run the same offline checks as `asc-aso-audit` against `./metadata`. Read `.agents/skills/asc-aso-audit/references/aso_rules.md` for the exact rules. Summary:

1. **Keyword waste** - tokens in `subtitle`/`name` that also appear in `keywords` (already indexed, wasted budget).
2. **Underutilized fields** - keywords < 90/100 chars, subtitle < 20/30 chars.
3. **Missing fields** - empty `subtitle`/`keywords`/`description`/`whatsNew`.
4. **Bad separators** - spaces after commas, semicolons, or pipes in `keywords`.
5. **Cross-locale gaps** - non-primary locale `keywords` identical to `en-US` (not localized).
6. **Description keyword coverage** - tracked keywords missing from the `description` (conversion, not indexing).

Metadata paths: app-info `metadata/app-info/{locale}.json` (`subtitle`); version `metadata/version/{latest}/{locale}.json` (`keywords`, `description`, `whatsNew`). Primary locale `en-US`.

## Phase 2: krankie Competitor Rank-Gap Analysis

Pull current rankings for VivaDicta + the 3 tracked competitors from the VPS (canonical history):

```bash
ssh lobster@openclawtail 'export PATH="$HOME/.bun/bin:$PATH"; krankie rankings --json'
```

Apps in the krankie DB:
- VivaDicta `6758147238` (own)
- Otter `1276437113`, Wispr Flow `6497229487`, Whisper Transcription `1668083311` (competitors, US)

### Steps

1. **Build a per-keyword rank table** for US: VivaDicta rank vs each competitor's rank (`current_rank`, null = not in top 200).
2. **Surface gaps**: keywords where **a competitor ranks (especially top-50) and VivaDicta is unranked or much worse**. These are the highest-value targets - a rival is capturing search traffic you are not.
3. **Rank gaps by competitor strength**: sort by best competitor rank ascending (a keyword where Otter is #3 and we are unranked outranks one where a competitor is #150).
4. **Diff against metadata tokens**: for each gap keyword, check whether its component tokens are present in `subtitle` + `name` + `keywords` of any locale. If the tokens are missing, that explains the gap and is an actionable add. If tokens are present but VivaDicta still doesn't rank, the issue is competition/authority, not coverage.
5. **Cross-field combo note**: remember keywords combine within a locale across title + subtitle + keywords. Flag combos enabled by adding a single token (e.g. adding `recorder` when `voice` is already indexed enables "voice recorder").

### Skip conditions

- VPS unreachable - run krankie locally on the MacBook (`krankie rankings --json`), noting the local DB may be sparse; or skip Phase 2 with a note.
- A keyword not tracked yet - add it: `krankie keyword add 6758147238 "<kw>" --store us` (and for competitors to compare).

## Output Format

```
### ASO Audit Report (krankie)

**App:** VivaDicta - Speech to Text | **Primary Locale:** en-US
**Metadata source:** metadata/version/X.Y.Z

#### Field Utilization
| Field | Value | Length | Limit | Usage |
...

#### Offline Checks
| # | Check | Severity | Field | Locale | Detail |
...
**Summary:** X errors, Y warnings across Z locales

#### Competitor Rank-Gap (krankie, US)
| Keyword | VivaDicta | Otter | Wispr Flow | Whisper Trans. | In metadata? | Action |
|---------|-----------|-------|------------|----------------|--------------|--------|
| voice typing | - | #2 | #1 | - | tokens present | competition, not coverage |
| dictation keyboard | #164 | - | #1 | - | partial | reinforce combo |

#### Recommendations
1. [Errors first]
2. [Keyword waste]
3. [Utilization]
4. [Highest gap opportunities by competitor strength]
```

## Notes

- Phase 1 works with zero network access - the audit is useful even if the VPS/krankie is down.
- No popularity data: prioritize by competitor rank, not popularity. If you later resubscribe to Astro, `asc-aso-audit` Phase 2 adds popularity + suggestions back.
- After metadata changes, run `krankie-rankings` to measure impact (ranks settle over 1-2 weeks).
- Related: `krankie-rankings` (dated rankings report), `asc-aso-audit` (Astro-based original).
