---
name: swift-clean-review
description: Full Clean Code audit of Swift code covering all principles. Use when the user asks for a complete clean code review, full audit, or comprehensive refactoring of a Swift file or module.
argument-hint: [file or directory]
allowed-tools: [Read, Bash, Edit, Glob, Grep]
---

# Swift Clean Code — Full Review

Perform a complete Clean Code audit of the provided Swift code, covering all principles from Robert Martin's book adapted to Swift.

## Arguments

The user provided: $ARGUMENTS

If a file path is given — read it. If a directory — find all `.swift` files and audit them. If no arguments — ask the user to specify.

## Instructions

### Step 1: Discover Files
- If a directory: `find $ARGUMENTS -name "*.swift" -not -path "*/build/*" -not -path "*/.build/*"`
- Read each file

### Step 2: Run All Checks in Order

For each file, check the following categories:

---

#### NAMES (Chapter 2)
- [ ] No single-letter or cryptic names (except loop indices in trivial loops)
- [ ] No abbreviations (except `id`, `url`, `uuid`, `api`)
- [ ] No noise words: `Data`, `Info`, `Object`, `Manager` added for nothing
- [ ] Types in PascalCase; values/functions in camelCase
- [ ] Booleans read as assertions: `is*`, `has*`, `can*`, `should*`
- [ ] Functions named as verb phrases: `fetchUser()`, `validateInput()`
- [ ] One consistent word per concept across the codebase: `fetch` vs `load` vs `get`
- [ ] Magic numbers extracted to named constants

---

#### FUNCTIONS (Chapter 3)
- [ ] Functions ≤ 20 lines (flag anything over 30)
- [ ] Each function does one thing
- [ ] One level of abstraction per function
- [ ] No more than 2 parameters (3+ → wrap in struct)
- [ ] No Boolean flag parameters
- [ ] No side effects hidden in query functions
- [ ] Command–Query Separation respected
- [ ] DRY: no duplicated logic (extract repeated blocks)
- [ ] `guard` used for early returns

---

#### COMMENTS (Chapter 4)
- [ ] No commented-out dead code
- [ ] No comments that explain **what** the code does (rename instead)
- [ ] No misleading or outdated comments
- [ ] Allowed: comments explaining **why** (workarounds, non-obvious invariants, legal)
- [ ] `// MARK: -` used correctly for section structure

---

#### FORMATTING (Chapter 5)
- [ ] Consistent indentation (4 spaces, no tabs)
- [ ] Related code grouped vertically; unrelated code separated by blank lines
- [ ] Functions declared near where they are called
- [ ] File is organized: types → properties → init → lifecycle → public methods → private methods

---

#### TYPES & CLASSES (Chapter 6, 10)
- [ ] Each type has a single responsibility
- [ ] No "God" objects (types doing 3+ unrelated things)
- [ ] Prefer `struct` over `class` for value semantics
- [ ] Dependencies injected via `init`, not via singletons
- [ ] Protocol used to define contracts for dependencies

---

#### ERROR HANDLING (Chapter 7)
- [ ] No `nil` returned to signal errors — use `throws` or `Result`
- [ ] Custom `Error` enums with meaningful cases
- [ ] No silent `catch { }` blocks
- [ ] No force unwrap (`!`) on external data (API responses, user input)
- [ ] `try?` only where the failure is genuinely inconsequential

---

#### TESTS (Chapter 9)
- [ ] Tests follow FIRST principles
- [ ] Each test has one assertion per behavior
- [ ] Tests named descriptively
- [ ] No real I/O in unit tests (network, file system, database)
- [ ] AAA pattern (Arrange, Act, Assert)

---

### Step 3: Report

For each file, produce a structured report:

```
## [FileName.swift]

### Critical Issues (must fix)
- Line X: [issue] — [suggested fix]

### Major Issues (should fix)
- Line X: [issue] — [suggested fix]

### Minor Issues (nice to fix)
- Line X: [issue] — [suggested fix]
```

Severity scale:
- **Critical**: bug-prone, crashes, silent errors, force unwraps on external data
- **Major**: SRP violations, functions > 50 lines, no error context, duplicated logic
- **Minor**: naming, comment noise, formatting

### Step 4: Apply Fixes

After showing the report, ask the user: "Apply all fixes automatically, or review file by file?"

- If auto: apply all fixes using Edit tool
- If file by file: apply fixes one file at a time and confirm after each

### Step 5: Summary

After all fixes:
```
## Clean Code Audit Summary
- Files reviewed: N
- Critical issues fixed: N
- Major issues fixed: N
- Minor issues fixed: N
- Files that need manual refactoring (structural): [list]
```
