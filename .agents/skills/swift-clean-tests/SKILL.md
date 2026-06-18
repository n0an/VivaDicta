---
name: swift-clean-tests
description: Review Swift unit tests based on Clean Code principles. Use when the user asks to check test quality, apply FIRST principles, review XCTest/Swift Testing structure, improve test naming, or audit test coverage strategy in Swift.
argument-hint: [file or code snippet]
allowed-tools: [Read, Bash, Edit, Glob, Grep]
---

# Swift Clean Tests

Audit and improve Swift tests per Clean Code (Robert Martin) — Chapter 9: Unit Tests, adapted to XCTest and Swift Testing framework.

## Arguments

The user provided: $ARGUMENTS

If a file path is given — read it. If no arguments — ask the user to paste the code or specify a file.

## FIRST Principles Checklist

### F — Fast
- Tests must run in milliseconds, not seconds
- No real network calls, no real database, no `Thread.sleep`
- Use protocol mocks or in-memory implementations for I/O

```swift
// BAD — hits real network
func testFetchUser() async throws {
    let service = UserService(network: URLSession.shared)
    let user = try await service.fetchUser(id: "1")
    XCTAssertEqual(user.name, "Alice")
}

// GOOD — uses mock
func testFetchUser() async throws {
    let network = MockNetworkClient(response: .success(fakeUserData))
    let service = UserService(network: network)
    let user = try await service.fetchUser(id: "1")
    XCTAssertEqual(user.name, "Alice")
}
```

### I — Independent
- Each test must set up its own state; never depend on another test's side effects
- Tests must pass in any order
- Use `setUp()` / `tearDown()` to reset shared state

### R — Repeatable
- Tests produce the same result every run: no random data, no system clock, no environment-specific paths
- Inject `Date`, `UUID`, random sources as dependencies

```swift
// BAD
let id = UUID().uuidString  // different every run

// GOOD
protocol IDGenerator { func generate() -> String }
struct FixedIDGenerator: IDGenerator { func generate() -> String { "fixed-test-id" } }
```

### S — Self-Validating
- A test must produce a clear pass/fail with no manual inspection
- Never use `print()` as verification — use `XCTAssert*` or `#expect`
- Failure messages must say what went wrong: `XCTAssertEqual(result, expected, "Expected sorted list")`

### T — Timely
- Write tests **before or alongside** the production code (TDD) — not after
- A test written after the fact often tests the implementation, not the behavior

---

## Clean Test Structure

### One Concept Per Test
- Each test verifies one logical behavior, not 5 things at once
- If a test has 3 different `XCTAssert` calls about unrelated things — split it

### Arrange–Act–Assert (AAA) Pattern
- **Arrange**: set up the system under test and inputs
- **Act**: call the function under test (one call)
- **Assert**: verify the result

```swift
func testOrderTotal_includesTax() {
    // Arrange
    let calculator = PriceCalculator(taxRate: 0.2)
    let items = [Item(price: 100)]
    
    // Act
    let total = calculator.total(for: items)
    
    // Assert
    XCTAssertEqual(total, 120.0)
}
```

### Descriptive Test Names
- Name format: `test_<subject>_<condition>_<expectedResult>` or a full sentence
- Bad: `testUser()`, `test1()`, `testFetchFails()`
- Good: `testFetchUser_whenNetworkFails_throwsNetworkError()`

### Minimal Mocking
- Mock only what you need to isolate the unit under test
- Don't mock value types, pure functions, or simple utilities
- Prefer protocol-based mocks over method swizzling or ObjC runtime tricks

### Test the Behavior, Not the Implementation
- Tests should not break when you refactor internals without changing behavior
- Don't test private methods directly — test through the public interface

### Swift Testing Framework (`@Test`, `#expect`)
- Prefer `swift-testing` for new test files (Xcode 16+)
- Use `@Suite` to group related tests
- `#expect(throws:)` for error assertions

```swift
@Suite("UserService")
struct UserServiceTests {
    @Test("throws notFound when user does not exist")
    func fetchUser_throwsNotFound() async {
        let service = UserService(network: MockNetworkClient(response: .notFound))
        await #expect(throws: UserError.notFound) {
            try await service.fetchUser(id: "missing")
        }
    }
}
```

---

## Instructions

1. Read the provided Swift test file(s)
2. Check each test against the FIRST principles and structure rules above
3. For each issue found, report:
   - Test name and line number
   - Violation type
   - Suggested fix
4. Apply fixes using Edit tool: rename tests, extract `setUp`, remove real I/O dependencies
5. For large structural changes (e.g., introducing a mock), show the plan and implement it
6. Show summary of issues found and fixed
