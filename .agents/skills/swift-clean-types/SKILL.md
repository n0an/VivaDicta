---
name: swift-clean-types
description: Review Swift classes, structs, enums, and protocols based on Clean Code principles. Use when the user asks to check class design, apply SRP, review protocol conformances, refactor types, or improve Swift architecture.
argument-hint: [file or code snippet]
allowed-tools: [Read, Bash, Edit, Glob, Grep]
---

# Swift Clean Types

Audit and refactor Swift types (classes, structs, enums, protocols, extensions) per Clean Code (Robert Martin) + Swift Protocol-Oriented Programming.

## Arguments

The user provided: $ARGUMENTS

If a file path is given — read it. If no arguments — ask the user to paste the code or specify a file.

## Checklist to Apply

### 1. Single Responsibility Principle (SRP)
- A type should have **one reason to change**
- A class that handles networking, parsing, AND storage violates SRP
- Count the nouns in a type's description: "handles users AND manages sessions AND formats dates" = 3 classes

```swift
// BAD — UserManager does everything
class UserManager {
    func fetchFromAPI() {}
    func saveToDatabase() {}
    func formatDisplayName() {}
    func sendAnalytics() {}
}

// GOOD — each type owns one concern
struct UserRepository { func fetch() throws -> User {} }
struct UserFormatter { func displayName(for user: User) -> String {} }
class UserAnalytics { func trackLogin() {} }
```

### 2. Small Types
- Classes/structs should have **~200 lines or fewer** (excluding comments and blanks)
- If you need to scroll to understand a type — it's too large
- Count public methods: more than 10 is a signal to split

### 3. High Cohesion
- Instance variables should be used by most methods of the class
- If a group of methods only uses a subset of instance variables — that's a new class

### 4. Prefer Value Types (Structs) Over Reference Types (Classes)
- Use `struct` by default; use `class` only when:
  - Identity matters (same instance must be shared)
  - Inheritance is required
  - Lifecycle must be managed (deinit needed)

```swift
// BAD — class for pure data
class Point { var x: Double; var y: Double }

// GOOD
struct Point { let x: Double; let y: Double }
```

### 5. Protocol-Oriented Design
- Depend on protocols, not concrete types (Dependency Inversion Principle)
- Inject dependencies via initializer, not via global state or singletons

```swift
// BAD
class OrderService {
    let network = URLSession.shared  // concrete, untestable
}

// GOOD
protocol NetworkClient { func fetch(_ request: URLRequest) async throws -> Data }
class OrderService {
    init(network: NetworkClient) { ... }
}
```

### 6. Open/Closed Principle
- Types should be **open for extension, closed for modification**
- Prefer adding conformances/extensions over modifying existing types
- Use protocols + extensions instead of subclassing for shared behavior

### 7. Avoid Massive View Controllers / God Objects
- In iOS: if a UIViewController/SwiftUI View has networking, business logic, AND persistence — split it
- Extract: `ViewModel` (state + logic), `Repository` (data), `Coordinator`/`Router` (navigation)

### 8. Encapsulate What Varies
- If a switch/if-else over a type tag appears in multiple places — replace with polymorphism or a protocol

### 9. Limit Extensions
- Extensions should group related functionality, not become dumping grounds
- Each extension should have a single topic: `// MARK: - UITableViewDataSource`
- Don't spread the core logic of a type across 10 extensions

### 10. Dependency Injection, Not Singletons
- Singletons make code hard to test and create hidden coupling
- Accept dependencies in `init` so they can be replaced in tests

## Instructions

1. Read the provided Swift file(s)
2. For each type violation found, report:
   - Type name and line number
   - Violation (from checklist above)
   - Suggested refactoring approach
3. Apply fixes where safe (rename, extract protocol, split extension)
4. For large structural changes (split class into two), describe the plan and ask for confirmation before modifying
5. Show summary of findings
