---
name: swift-clean-names
description: Review and fix Swift naming conventions based on Clean Code principles. Use when the user asks to check names, review identifiers, rename variables/functions/types, or improve readability of Swift code.
argument-hint: [file or code snippet]
allowed-tools: [Read, Bash, Edit, Glob, Grep]
---

# Swift Clean Names

Audit and fix naming in Swift code per Clean Code (Robert Martin), adapted to Swift conventions.

## Arguments

The user provided: $ARGUMENTS

If a file path is given — read it. If no arguments — ask the user to paste the code or specify a file.

## Checklist to Apply

### 1. Intention-Revealing Names
- Name must answer: **what it is, why it exists, how it is used**
- Bad: `d`, `data`, `info`, `temp`, `result`, `val`, `flag`
- Good: `elapsedTimeInDays`, `userAuthToken`, `isPaymentConfirmed`

```swift
// BAD
let d = Date().timeIntervalSince1970
var lst: [Any] = []

// GOOD
let registrationTimestamp = Date().timeIntervalSince1970
var pendingOrders: [Order] = []
```

### 2. Avoid Disinformation
- Don't use names that suggest a different type: `accountList` if it's not a `List`/array
- Don't use names that differ only slightly: `userController` vs `usersController`
- Don't embed type in name (no Hungarian notation): `strName`, `arrItems`

### 3. Swift Type Naming (PascalCase)
- Classes, structs, enums, protocols, typealiases: `UserProfile`, `PaymentError`, `NetworkService`
- Protocol names describe capability or role: `Authenticatable`, `DataPersisting`, `OrderProcessing`
- Avoid suffix noise: `ManagerClass`, `HelperObject`, `UtilStruct`

### 4. Swift Value/Function Naming (camelCase)
- Variables, constants, functions, parameters: `userName`, `fetchUserProfile()`, `isLoggedIn`
- Booleans should read as assertions: `isLoading`, `hasError`, `canSubmit`, `shouldReload`
- Functions should read as verb phrases: `fetchUser()`, `validateInput()`, `presentError(_:)`

### 5. No Mental Mapping
- Don't use single-letter names except in short, well-known scopes (`for i in 0..<count`)
- Loop variables in complex logic must be named: `for order in pendingOrders`

### 6. No Abbreviations
- `usr` → `user`, `btn` → `button`, `idx` → `index`, `cnt` → `count`
- Exception: universally accepted abbreviations (`url`, `id`, `uuid`, `api`)

### 7. One Word Per Concept
- Pick one: `fetch` vs `get` vs `retrieve` vs `load` — use it consistently
- Pick one: `manager` vs `service` vs `coordinator` — use it consistently

### 8. Searchable Names
- Avoid magic numbers: extract to named constants
- `let maxRetryCount = 3` not `if retries < 3`

### 9. No Noise Words
- `UserData` vs `User` — if `Data` adds nothing, drop it
- `ProductInfo`, `OrderObject`, `PaymentEntity` — the suffix is noise

## Instructions

1. Read the provided Swift file(s)
2. For each naming violation found, list:
   - Line number
   - Current name
   - Violation type (from checklist above)
   - Suggested name
3. Apply all fixes directly using Edit tool
4. Show a summary: how many names were fixed per category
