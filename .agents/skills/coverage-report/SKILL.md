---
name: coverage-report
description: Measure VivaDicta test code coverage from the terminal. Use when asked what the test coverage is, a module's or the whole-app coverage %, which lines/files are covered, to get coverage without opening Xcode, or to see coverage after writing tests. Covers both the fast per-SPM-module path (swift test + llvm-cov) and the canonical whole-app path (xcodebuild + xccov), and which first-party targets count.
---

# Coverage Report

One script, `scripts/coverage/coverage.sh`, measures code coverage two ways. **Coverage is a runtime metric - you must run the tests to get it** (it records which executable lines actually ran). It is *not* the same as the test/prod LOC ratio, which is a static count - that lives in the `loc-report` skill.

## Run it

```bash
# Canonical: full test plan in the simulator. Overall + per-target.
scripts/coverage/coverage.sh app

# ...plus per-file rows for specific files (e.g. after writing ViewModel tests):
scripts/coverage/coverage.sh app ChatViewModel.swift SmartSearchChatViewModel.swift

# Fast: one SPM module via swift test on the macOS host (no simulator).
scripts/coverage/coverage.sh module CloudTranscription

# Most complete: clean DerivedData -> full plan -> auto-fill any dropped module
# row from the module path -> one merged 16-module table. Slow (~10-15 min).
scripts/coverage/coverage.sh full
```

Env overrides: `DESTINATION` (simulator, default iPhone 17 Pro Max), `RESULT` (`.xcresult` path).

## The two paths, and when to use which

| | `app` (xcodebuild + `xccov`) | `module` (`swift test` + `llvm-cov`) |
|---|---|---|
| Scope | whole app + extensions + all modules | one SPM module |
| Runs on | iOS Simulator (slow) | macOS host (fast - seconds) |
| Reads from | a `.xcresult` bundle | the test binary + `default.profdata` under `.build` |
| Use for | the **canonical** number, the app target | tight iteration on one module while writing its tests |

The app target itself (`VivaDicta.app`) can only be measured the `app` way - `swift test` cannot build an iOS app.

**`full` is `app` + a clean rebuild + auto-fill.** It deletes DerivedData first (a clean relink recovers most dropped per-target rows - see the wobble caveat below), runs the full plan, then for any module whose row still dropped or came back `0/0` it runs the `module` path and splices the number in. Result: a number for *every* module in one command. Filled rows are labeled `module-floor` (own-tests-only - a floor for app-exercised modules like TextProcessing). Use `full` when you want the complete, reliable per-module table; use `app` for a fast warm-build check.

## Caveats that bite

- **macOS-host runs exclude iOS-only files**, so a module's `module`-path total differs slightly from its Xcode/`xccov` number (e.g. CloudTranscription reads ~2,231 lines via `swift test` vs ~3,073 in Xcode). Use `module` for *relative* per-file progress; trust `app`/`xccov` for the canonical total.
- **The aggregate per-target rows are non-deterministic.** An SPM module is a static lib linked into both the app and its own test bundle; the linker's cross-binary dedup sometimes leaves a module without a clean mapping, so its standalone row **drops out of some runs** (or returns `0/0`) - and which modules drop shifts run to run. The code is still tested. A **clean build recovers most rows** (~18/21 vs ~13/21 incremental) - that's what `full` does, filling any still-dropped row from the `module` path. For a deterministic single-module number, use the `module` path.
- The **headline is dominated by the ~73k-line `VivaDicta.app` target (~9%)** - it is ~80% of the code, so module-level test work barely moves the global %. Judge progress by **per-logic-module coverage** and **per-file** ViewModel rows, not the headline.
- After a toolchain bump, `rm -rf Modules/<Module>/.build` once before the `module` path (stale `.swiftmodule` import error).

## First-party filtering happens in the script, not the test plan

`VivaDicta/VivaDictaTestPlan.xctestplan` has **no `defaultOptions.codeCoverage` pin** (it was removed 2026-06-20), so Xcode gathers coverage for **all** targets - Firebase/Google/GUL/KeyboardKit/etc. (FirebaseCrashlytics alone is ~10k lines) are in the bundle. So the **raw bundle % is meaningless (~25%)**. `coverage.sh` filters to first-party at report time (`first_party_overall`): the **16 production modules + `VivaDicta` app + the 4 extensions**, with `TestUtilities` / `*Mocks` / `*Tests` excluded → first-party overall ~14%. This is why the script, not the test plan, owns the filtering - adding/removing a module no longer requires editing the test plan. **If you ever call `xccov` by hand, filter to first-party yourself** or you'll report the polluted number. The full terminal-coverage reference also lives in `AGENTS.md` under "Test Coverage".
