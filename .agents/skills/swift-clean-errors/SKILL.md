---
name: swift-clean-errors
description: Review Swift error handling based on Clean Code principles. Use when the user asks to check error handling, review optionals usage, improve throws/Result/async patterns, or audit nil handling in Swift code.
argument-hint: [file or code snippet]
allowed-tools: [Read, Bash, Edit, Glob, Grep]
---

# Swift Clean Errors

Audit and fix error handling in Swift code per Clean Code (Robert Martin), adapted to Swift's error system.

## Arguments

The user provided: $ARGUMENTS

If a file path is given — read it. If no arguments — ask the user to paste the code or specify a file.

## Checklist to Apply

### 1. Use `throws` Instead of Returning Optional or Bool
- Functions that can fail due to an external condition should `throw`, not return `nil`
- `nil` return hides the reason for failure; a thrown `Error` explains it

```swift
// BAD
func parseJSON(from data: Data) -> User? { ... }

// GOOD
enum ParseError: Error {
    case invalidFormat
    case missingRequiredField(String)
}
func parseJSON(from data: Data) throws -> User { ... }
```

### 2. Define Meaningful Error Types
- Use enums conforming to `Error` with associated values where the context matters
- Don't use `NSError`, `String`, or raw integers as errors
- Error cases should read like sentences: `.networkTimeout`, `.unauthorized`, `.notFound(id: String)`

```swift
// BAD
func fetchUser(id: String) throws {
    throw NSError(domain: "App", code: 404, userInfo: nil)
}

// GOOD
enum UserError: Error {
    case notFound(id: String)
    case unauthorized
    case networkFailure(underlying: Error)
}
```

### 3. Don't Return `nil` — Throw or Use `Result`
- `nil` as a signal is fine for truly optional values (user has no middle name)
- `nil` as an error signal is bad — use `throws` or `Result<T, Error>`

### 4. Provide Context with Errors
- Catch errors at the right level — where you have enough context to handle or enrich them
- Don't silently swallow errors: `catch { }` is almost always wrong
- Add context when rethrowing: wrap the underlying error with your domain error

```swift
// BAD
do {
    try saveUser(user)
} catch { } // silent swallow

// GOOD
do {
    try saveUser(user)
} catch {
    logger.error("Failed to save user \(user.id): \(error)")
    throw UserError.persistenceFailed(underlying: error)
}
```

### 5. Handle Errors at One Level
- Don't mix error-handling concerns across layers
- Network layer throws `NetworkError`; domain layer catches and maps to `DomainError`
- UI layer catches `DomainError` and maps to user-facing messages

### 6. Don't Pass `nil` as a Parameter
- A function that accepts optional parameters to signal modes is a design smell
- Split into two functions or use a config struct

```swift
// BAD
func displayAlert(title: String, message: String?) { ... }

// GOOD
func displayAlert(title: String, message: String) { ... }
func displaySimpleAlert(title: String) { ... }
```

### 7. Guard Against `nil` at Boundaries, Not Everywhere
- Validate optionals at entry points (view layer, API response parsing)
- Internal code should work with non-optional types

```swift
// BAD — force unwrap in business logic
let name = user.name!

// GOOD — guard at the boundary
guard let rawUser = response.user else { throw ParseError.missingUser }
let user = try mapToUser(rawUser)  // non-optional from here on
```

### 8. `try?` — Use With Caution
- `try?` discards the error — only use when you genuinely don't care why it failed
- Never use `try?` on code that can fail for important reasons (network, database, parsing)

### 9. Async/Await Error Handling
- In `async` functions, use `throws` consistently; don't use callbacks with optional errors
- Structured concurrency propagates errors naturally — use it

```swift
// BAD — callback with optional error
func fetchUser(completion: (User?, Error?) -> Void) {}

// GOOD
func fetchUser() async throws -> User {}
```

### 10. `fatalError` and `precondition` — Developer Errors Only
- Use `fatalError` / `preconditionFailure` only for programmer errors (logic bugs, impossible states)
- Never use them for runtime errors that depend on external input or network state

## Instructions

1. Read the provided Swift file(s)
2. For each error handling issue found, report:
   - Line number
   - Issue type (from checklist above)
   - Suggested fix
3. Apply fixes using Edit tool
4. Show summary of all issues found and fixed
