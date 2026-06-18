---
name: swift-clean-functions
description: Review and refactor Swift functions based on Clean Code principles. Use when the user asks to check function design, split large functions, reduce function arguments, review closures, or improve function structure in Swift code.
argument-hint: [file or code snippet]
allowed-tools: [Read, Bash, Edit, Glob, Grep]
---

# Swift Clean Functions

Audit and refactor functions/methods in Swift code per Clean Code (Robert Martin), adapted to Swift idioms.

## Arguments

The user provided: $ARGUMENTS

If a file path is given — read it. If no arguments — ask the user to paste the code or specify a file.

## Checklist to Apply

### 1. Small Functions
- Functions should be **20 lines or fewer**; ideal is under 10
- If a function needs a comment to explain a block — that block is a new function
- Each `if`/`guard`/`for` body should ideally be a single function call

```swift
// BAD — 40-line function doing setup + fetch + parse + display
func loadUserProfile() { ... }

// GOOD — orchestrator calling small focused functions
func loadUserProfile() {
    showLoadingState()
    fetchUserData { [weak self] result in
        self?.handleUserDataResult(result)
    }
}
```

### 2. Do One Thing
- A function does one thing if you cannot extract another function from it with a name that is not a restatement of its implementation
- Section comments inside a function = it does more than one thing

### 3. One Level of Abstraction
- All statements in a function should be at the **same level of abstraction**
- Don't mix high-level orchestration with low-level detail in one function

```swift
// BAD — mixing levels
func submitOrder() {
    let json = try? JSONEncoder().encode(order)  // low-level
    coordinator.navigateToConfirmation()          // high-level
}

// GOOD
func submitOrder() {
    let payload = encodeOrder()
    sendToAPI(payload)
    navigateToConfirmation()
}
```

### 4. Function Arguments
- **Ideal: 0 arguments** (niladic)
- **Good: 1 argument** (monadic)
- **Acceptable: 2 arguments** (dyadic) — document the order
- **Avoid: 3+ arguments** — group into a struct/model
- **Never: flag (Bool) arguments** — split into two functions

```swift
// BAD
func createUser(name: String, email: String, age: Int, isAdmin: Bool, isVerified: Bool) {}

// GOOD
struct UserCreationRequest {
    let name: String
    let email: String
    let age: Int
    let role: UserRole
    let verificationStatus: VerificationStatus
}
func createUser(_ request: UserCreationRequest) {}
```

### 5. No Side Effects
- A function that is named `getUser()` must not save to database, mutate global state, or send analytics
- If a function has a side effect, its name must reveal it: `fetchAndCacheUser()`

### 6. Command–Query Separation
- A function either **does something** (command) or **answers something** (query) — never both
- `isValid()` must return Bool without mutating state
- `save()` must save and return nothing (or throw)

### 7. Prefer Exceptions to Error Codes (Use `throws`)
- Don't return `nil` to signal errors from functions that should always produce a value
- Use `throws` + `Error` enum instead of Bool success flags or optional returns

```swift
// BAD
func parseConfig(from data: Data) -> Config? { ... }

// GOOD
func parseConfig(from data: Data) throws -> Config { ... }
```

### 8. DRY — Don't Repeat Yourself
- Any code block that appears 2+ times must be extracted into a named function
- Parameterize what differs; name what stays the same

### 9. Swift-Specific: Trailing Closures & Clarity
- Use trailing closure syntax only when the closure is the last argument AND its purpose is clear
- Name closure parameters when the type alone is ambiguous: `completion: (Result<User, Error>) -> Void`
- Avoid deeply nested closures — extract each level into a named function or use async/await

### 10. `guard` for Early Exit
- Use `guard` to eliminate deep nesting and handle invalid states at the top
- Never write `if let x = x { ... }` for the happy path; use `guard let`

## Instructions

1. Read the provided Swift file(s)
2. For each function violation found, report:
   - Function name and line number
   - Violation type (from checklist above)
   - Suggested refactoring
3. Apply fixes using Edit tool — extract helper functions, rename, restructure
4. Show summary: violations found vs fixed
