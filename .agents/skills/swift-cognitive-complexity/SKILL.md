---
name: swift-cognitive-complexity
description: Measure and reduce Cognitive Complexity in Swift code based on "Cognitive Complexity — A new way of measuring understandability" by G. Ann Campbell (SonarSource). Use when the user asks to check cognitive complexity, reduce nesting, simplify control flow, untangle complex conditions, or make Swift functions easier to understand.
argument-hint: [file or code snippet]
allowed-tools: [Read, Bash, Edit, Glob, Grep]
---

# Swift Cognitive Complexity

Measure and reduce Cognitive Complexity in Swift code per G. Ann Campbell's paper (SonarSource, 2023).

Cognitive Complexity measures **mental effort to understand code** — not just path count (Cyclomatic Complexity). Deeply nested code costs more than flat code with the same branch count.

## Arguments

The user provided: $ARGUMENTS

If a file path is given — read it. If no arguments — ask the user to paste the code or specify a file.

---

## Scoring Rules

### A — Structural increments (+1 each, plus nesting penalty)

These structures break linear flow and add nesting:

| Swift construct | Increment |
|---|---|
| `if`, `else if`, `else` | +1 (+ nesting level) |
| `guard` … `else` | +1 (+ nesting level) |
| `switch` | +1 (+ nesting level) |
| `for`, `while`, `repeat`…`while` | +1 (+ nesting level) |
| `catch` | +1 (+ nesting level) |
| Ternary `? :` | +1 (+ nesting level) |
| Nested closure / trailing closure | +1 (+ nesting level) |
| Recursive call | +1 |

### B — Nesting penalty

Every structural increment inside another structural scope adds **+1 per nesting level**:

```
func f() {
    if a {           // +1 (level 0)
        for b in c { // +2 (level 1 → +1 base + 1 nesting)
            if d {   // +3 (level 2 → +1 base + 2 nesting)
            }
        }
    }
}
// Total: 6
```

Closures count as an extra nesting level:

```swift
items.forEach { item in  // +1 (closure, level 0)
    if item.isValid {    // +2 (level 1)
        item.process()
    }
}
// Total: 3
```

### C — Flat increments (+1, no nesting penalty)

These add complexity without adding nesting depth:

| Swift construct | Increment |
|---|---|
| `break` / `continue` to label | +1 |
| Sequence of mixed logical operators | +1 per mixed sequence |

**Mixed logical operators:** each contiguous sequence of the same operator is one increment; switching operator type starts a new increment.

```swift
// +1: one sequence of &&
if a && b && c { }

// +2: two sequences (&&, then ||)
if a && b || c { }

// +3: three sequences (&& → || → &&)
if a && b || c && d || e { }
```

---

## Thresholds (SonarQube defaults)

| Score | Signal |
|---|---|
| 0–15 | Good |
| 16–25 | Review candidate |
| 25+ | Refactor |

---

## Key Differences from Cyclomatic Complexity

| | Cyclomatic | Cognitive |
|---|---|---|
| Switch with 5 cases | +5 | +1 |
| `&&` and `\|\|` per operator | +1 each | +1 per mixed sequence |
| Nesting depth | ignored | multiplier |
| Recursion | ignored | +1 |
| Nested closures | ignored | +1 per level |

---

## Swift-Specific High-Complexity Patterns

### 1. Nested closures
```swift
// HIGH: each closure adds a nesting level
fetchUser { user in           // +1
    fetchOrders(for: user) { orders in  // +2
        orders.forEach { order in       // +3
            if order.isPending {        // +4
            }
        }
    }
}
// Total: 10

// LOW: async/await flattens nesting
let user = try await fetchUser()
let orders = try await fetchOrders(for: user)
for order in orders where order.isPending { }
// Total: 1
```

### 2. Guard stacking vs nested ifs
```swift
// HIGH: nested ifs
func process(_ input: String?) {
    if let input = input {        // +1
        if !input.isEmpty {       // +2
            if input.count > 3 {  // +3
                handle(input)
            }
        }
    }
}
// Total: 6

// LOW: guards keep code flat
func process(_ input: String?) {
    guard let input = input else { return }  // +1
    guard !input.isEmpty else { return }     // +1
    guard input.count > 3 else { return }    // +1
    handle(input)
}
// Total: 3
```

### 3. Complex boolean conditions
```swift
// HIGH
if user.isActive && !user.isBanned || user.isAdmin && config.allowAdminOverride { }
// +3 (&&, then ||, then &&)

// LOW: extract to named computed property or function
if user.canAccess(with: config) { }
// +1
```

### 4. Switch with side effects
```swift
// HIGH: complex switch with nested logic inside cases
switch state {        // +1
case .loading:
    if retryCount > 3 {  // +2
        showError()
    } else {             // +1
        retry()
    }
case .ready:
    if data.isEmpty {    // +2
        showEmpty()
    }
default: break
}
// Total: 6

// LOW: delegate case logic to functions
switch state {  // +1
case .loading: handleLoading()
case .ready:   handleReady()
default: break
}
// Total: 1
```

---

## Instructions

1. Read the provided Swift file(s)
2. For each function/method/closure, calculate the Cognitive Complexity score:
   - Walk the body, tracking current nesting depth
   - Apply rules A, B, C above
   - Sum all increments
3. Report each function with score ≥ 5:

```
## [FileName.swift]

| Function | Score | Threshold |
|---|---|---|
| processPayment() | 28 | ⛔ Refactor |
| validateInput() | 18 | ⚠️ Review |
| formatDate() | 4 | ✅ Good |

### processPayment() — Score: 28
Breakdown:
- Line 12: `if status == .pending` → +1 (level 0)
- Line 14: `for item in cart` → +2 (level 1)
- Line 16: `if item.isValid` → +3 (level 2)
- Line 19: `a && b || c` → +2 (mixed operators)
...

Suggested refactoring:
[specific extract-function suggestions]
```

4. Apply fixes using Edit tool:
   - Extract deeply nested closure bodies into named functions
   - Replace nested `if let` chains with `guard` statements
   - Extract complex boolean conditions into named computed properties or functions
   - Extract switch case bodies into dedicated functions

5. Recalculate scores after refactoring and show before/after comparison
