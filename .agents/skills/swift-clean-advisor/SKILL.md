---
name: swift-clean-advisor
description: Model-invoked skill that automatically guides Clean Code principles when writing or reviewing Swift code. Activates when creating new Swift files, implementing Swift functions or types, or when the user mentions clean code, SOLID, refactoring, or code quality in a Swift context.
version: 1.0.0
---

# Swift Clean Code Advisor

This skill activates automatically when you are writing or reviewing Swift code to ensure Clean Code principles (Robert Martin) are applied throughout.

## When This Skill Applies

Activate when:
- Creating or editing `.swift` files
- Implementing new Swift functions, classes, structs, enums, or protocols
- The user mentions: "clean code", "SOLID", "refactor", "code quality", "naming", "best practices" in a Swift context
- Reviewing existing Swift code for quality

## Core Principles to Enforce (Swift Edition)

### While Writing New Code

**Names first:**
- Choose the name before writing the body; if you can't name it cleanly, the design is wrong
- Types: PascalCase. Values/functions: camelCase. Booleans: `is*`/`has*`/`can*`

**Functions:**
- Write the function body; if it exceeds ~15 lines, immediately extract helper functions
- Zero or one parameter is ideal; two is acceptable; three requires a struct
- No `Bool` parameters — split into two functions

**Types:**
- Default to `struct` (value type) unless reference semantics are required
- Each type owns one concept; if you find yourself writing "and" in the type description, split it
- Inject dependencies via `init`; avoid `shared`, `.default`, `.main` singletons in domain logic

**Error handling:**
- Functions that can fail on external input always `throw`; never return `nil` to signal errors
- Name your errors: `enum UserError: Error { case notFound(id: String) }`
- Never use `catch { }` without at minimum logging the error

**Comments:**
- Write zero comments by default
- Add a comment only when the WHY is non-obvious (workaround, hidden constraint, non-obvious invariant)
- Never comment WHAT the code does — rename it instead

### While Reviewing Existing Code

Flag immediately:
1. Force unwrap (`!`) on any value derived from external input (API, user input, file system)
2. Functions longer than 30 lines — suggest extraction
3. Types with more than one responsibility — suggest split
4. `catch { }` with no logging or rethrowing
5. Magic numbers or strings without named constants
6. Repeated code blocks (2+ occurrences) — suggest extraction

### Swift-Specific Reminders

- Prefer `guard let` over nested `if let` for the happy path
- Use `async/await` over callback-based APIs for new code
- Conform to a protocol to define a seam for testing; don't test against concrete URLSession/CoreData
- Organize files: `// MARK: - Properties`, `// MARK: - Lifecycle`, `// MARK: - Public`, `// MARK: - Private`
- Extensions for protocol conformances: one extension per protocol, marked with `// MARK: - ProtocolName`

## Output Style

When this skill is active, integrate Clean Code guidance naturally into your responses:
- When writing code, produce clean code directly — don't write bad code and then suggest cleaning it
- When you spot a violation in existing code, point it out concisely: "Line 42: `d` → rename to `elapsedDays` (intention-revealing name)"
- Keep guidance brief and actionable; no lectures unless the user asks for explanation
