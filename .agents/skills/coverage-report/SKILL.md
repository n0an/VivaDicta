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

## Caveats that bite

- **macOS-host runs exclude iOS-only files**, so a module's `module`-path total differs slightly from its Xcode/`xccov` number (e.g. CloudTranscription reads ~2,231 lines via `swift test` vs ~3,073 in Xcode). Use `module` for *relative* per-file progress; trust `app`/`xccov` for the canonical total.
- **The aggregate per-target rows are non-deterministic.** A module statically linked into both its test bundle and the app can get its coverage merged into another binary, so its standalone row **drops out of some runs** (CloudTranscription appears in one run, AICore/AIKit in another). The code is still tested - get a reliable per-module number with the `module` path. This also makes the **overall %** wobble ~1-2 points run to run.
- The **headline is dominated by the ~73k-line `VivaDicta.app` target (~7%)** - it is ~80% of the code, so module-level test work barely moves the global %. Judge progress by **per-logic-module coverage** and **per-file** ViewModel rows, not the headline.
- After a toolchain bump, `rm -rf Modules/<Module>/.build` once before the `module` path (stale `.swiftmodule` import error).

## The first-party-only requirement

`VivaDicta/VivaDictaTestPlan.xctestplan` must pin `defaultOptions.codeCoverage` to an explicit `targets` list of **only first-party targets** (16 SPM modules + `VivaDicta` + the 4 extensions = 21). If that key is absent, Xcode gathers coverage for ALL targets and Firebase/Google/GUL/KeyboardKit/etc. (FirebaseCrashlytics alone is ~10k lines) pollute the number. Exclude every `*Mocks` and `*Tests` target too. Validate edits with `python3 -c "import json; json.load(open('VivaDicta/VivaDictaTestPlan.xctestplan'))"` (`plutil -lint` rejects the `.xctestplan` extension even when the JSON is valid). The full terminal-coverage reference also lives in `AGENTS.md` under "Test Coverage".
