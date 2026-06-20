---
name: loc-report
description: Count Swift lines of code across the VivaDicta codebase and refresh the production-vs-test history chart. Use when asked how many LOC / lines of code the project has, for a codebase-size or LOC breakdown by SPM module / main app / extension, how big a module or extension is, the prod-vs-test ratio, or to update / regenerate the LOC growth chart embedded in documentation/Module-Architecture.md.
---

# LOC Report

One script, `scripts/loc/loc_history.py`, answers two related questions:

- **breakdown** - how much Swift code exists right now, grouped into SPM modules, the main app, app extensions, and the watch app, split prod vs test (working-tree snapshot).
- **chart** - how that has grown over git history, rendered as the production-vs-test line chart embedded in `documentation/Module-Architecture.md` (the "Codebase size" section).

## Run it

```bash
python3 scripts/loc/loc_history.py            # breakdown table, then refresh the chart
python3 scripts/loc/loc_history.py breakdown  # snapshot table only (read-only, no file writes)
python3 scripts/loc/loc_history.py chart      # refresh CSV + SVG + PNG only
```

Pure stdlib; the PNG step shells out to `rsvg-convert` (`brew install librsvg`). If it is missing, the script prints the exact manual conversion command and still writes the CSV + SVG.

## Counting rule

A "line of code" is a non-blank Swift source line that does **not** start with `//`. `Package.swift` manifests are ignored. A file is **test** when it sits under a `*Tests` directory, under the `TestUtilities` module, or its name ends `Tests.swift` / `Spec(s).swift`; otherwise **prod**. Both lenses share this rule, so the breakdown's grand total reconciles with the chart's latest data point (small drift = uncommitted working-tree edits).

This is a different lens from `cloc`: it does not strip `/* ... */` block comments, so totals run slightly higher than a `cloc` count. That is intentional - it keeps the snapshot consistent with the historical chart, which has always used this rule.

## Outputs and where they live

| File | Tracked? | Purpose |
|---|---|---|
| `scripts/loc/loc_history.py` | yes | the script |
| `scripts/loc/loc_history.csv` | yes | per-day `date,loc_prod,loc_test`, regenerated from git history each run |
| `scripts/loc/loc_history.svg` | yes | intermediate render |
| `documentation/assets/loc_history.png` | yes | the committed chart, embedded by `documentation/Module-Architecture.md` |

The chart walks `git log`, sampling the **last commit of each calendar day**, so a refresh only adds a new point once today's work is committed. The working-tree breakdown, by contrast, reflects uncommitted changes immediately.

## When refreshing the chart, also

- **Commit `documentation/assets/loc_history.png`** alongside the change that moved the LOC - it is the artifact the docs render. The CSV/SVG update too; commit them for an inspectable trail.
- **Re-check the prose** in `documentation/Module-Architecture.md` ("Codebase size" intro). It says `~57k-line production codebase`; bump that figure if production crosses a round number.
- This is the chore behind past `Update LOC history chart` commits - run it after a modularization extraction or a test-coverage push so the chart stays current.
