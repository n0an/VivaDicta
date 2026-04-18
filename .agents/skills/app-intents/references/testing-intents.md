# Testing App Intents

App Intents are plain Swift structs — they're directly testable with Swift Testing (or XCTest). The surface that's *not* unit-testable (Siri phrase recognition, Spotlight ranking) needs to be validated on device or via tooling.

## Unit-testing an intent

Instantiate the intent, assign `@Parameter` values, call `perform()`:

```swift
import Testing
import AppIntents
@testable import MyApp

@Suite
struct RefreshFeedIntentTests {
    @Test
    func refreshReturnsCount() async throws {
        var intent = RefreshFeedIntent()
        intent.folder = FolderEntity(id: UUID(), name: "Morning Reads")

        let result = try await intent.perform()

        #expect(result.value == 42)   // the chained-returns-value
    }
}
```

Key points:

- `@Parameter`-wrapped properties are writable from outside the struct in test code. Assign directly (`intent.folder = ...`).
- `perform()` is `async throws`. Use `#expect(throws:)` for error paths.
- Don't run full intent validation (Siri phrase matching, metadata extraction) in unit tests. That's the system's job; your test covers the *behavior* inside `perform()`.

## Mocking dependencies

`AppDependencyManager` is the same registry used by production code. Register test doubles at the top of the test suite:

```swift
protocol FeedStoreType: Sendable {
    func refresh() async throws -> Int
}

final class MockFeedStore: FeedStoreType {
    var refreshCallCount = 0
    func refresh() async throws -> Int {
        refreshCallCount += 1
        return 7
    }
}

@Suite
struct RefreshFeedIntentTests {
    init() {
        AppDependencyManager.shared.add { MockFeedStore() as FeedStoreType }
    }

    @Test
    func callsStoreExactlyOnce() async throws {
        let intent = RefreshFeedIntent()
        _ = try await intent.perform()

        // Read the mock back by resolving the dependency the same way the intent did
        let store = AppDependencyManager.shared.resolve(FeedStoreType.self) as! MockFeedStore
        #expect(store.refreshCallCount == 1)
    }
}
```

Design dependencies as *protocols*, not concrete classes. The intent declares `@Dependency var store: FeedStoreType`; production registers the real store; tests register a mock. No need to subclass or stub closures.

Reset between tests by re-registering in `init()` — the registry replaces prior bindings:

```swift
@Suite
struct RefreshFeedIntentTests {
    init() {
        AppDependencyManager.shared.add { MockFeedStore() as FeedStoreType }
    }
}
```

## Testing entities and queries

Entity creation:

```swift
@Test
func entityMapsFromModel() {
    let article = Article(id: UUID(), title: "Hello", summary: "World")
    let entity = ArticleEntity(article: article)

    #expect(entity.id == article.id)
    #expect(entity.title == "Hello")
}
```

`EntityQuery` lookups:

```swift
@Test
func queryById() async throws {
    AppDependencyManager.shared.add { MockArticleStore() as ArticleStore }

    let query = ArticleEntityQuery()
    let ids = [fixtures.articleA.id, fixtures.articleB.id]
    let results = try await query.entities(for: ids)

    #expect(results.count == 2)
    #expect(Set(results.map(\.id)) == Set(ids))
}

@Test
func queryByString() async throws {
    AppDependencyManager.shared.add { MockArticleStore() as ArticleStore }

    let query = ArticleEntityQuery()
    let results = try await query.entities(matching: "swift")

    #expect(results.contains { $0.title.contains("Swift") })
}
```

`EnumerableEntityQuery`:

```swift
@Test
func allFoldersReturnsFullList() async throws {
    let query = FolderEntityQuery()
    let all = try await query.allEntities()
    #expect(all.count == 5)
}
```

`EntityPropertyQuery` (predicate + sort):

```swift
@Test
func articlesSortedByDate() async throws {
    let query = ArticleEntityQuery()
    let predicates: [Predicate<ArticleEntity>] = [
        #Predicate { $0.title.contains("iOS") }
    ]
    let sorted = try await query.entities(
        matching: predicates,
        mode: .and,
        sortedBy: [EntityQuerySort(by: \.$publishedAt, order: .descending)],
        limit: 10
    )

    #expect(sorted.first?.publishedAt ?? .distantPast >= sorted.last?.publishedAt ?? .distantFuture)
}
```

## Testing error paths

`throws` paths use `#expect(throws:)`:

```swift
@Test
func missingFolderThrows() async throws {
    AppDependencyManager.shared.add { EmptyStore() as ArticleStore }

    var intent = OpenArticleIntent()
    intent.target = ArticleEntity(id: UUID(), title: "")   // id that won't resolve

    await #expect(throws: ArticleIntentError.notFound) {
        _ = try await intent.perform()
    }
}
```

Prefer specific error types over `Error.self` — the assertion actually verifies the intent threw the right error, not just *any* error.

## Testing the `AppShortcutsProvider`

You can't test phrase matching (that's the system), but you can verify the provider's shape:

```swift
@Test
func providerExposesExpectedIntents() {
    let shortcuts = ReaderShortcuts.appShortcuts
    let titles = shortcuts.map { $0.shortTitle }

    #expect(titles.contains("Refresh Feed"))
    #expect(titles.contains("Open Article"))
    #expect(shortcuts.count <= 10)   // hard limit
}
```

Use this as a guard against someone accidentally removing a shortcut during a refactor.

## Testing snippet intents

`SnippetIntent.perform()` is supposed to be pure — perfect for unit tests. Call it, inspect the returned view via `result.view`:

```swift
@Test
func snippetRendersCurrentCount() async throws {
    AppDependencyManager.shared.add {
        MockDashboardStore(unreadCount: 42) as DashboardStore
    }

    let intent = DashboardSnippetIntent()
    let result = try await intent.perform()

    // The returned view is a SwiftUI View; verify it was constructed without error.
    // Assert on the data that drove the view, not on SwiftUI internals.
    let store = AppDependencyManager.shared.resolve(DashboardStore.self) as! MockDashboardStore
    #expect(store.unreadCount == 42)
}
```

Do **not** try to assert on SwiftUI view hierarchies — use the dependency's observed state as the proxy.

## What you can't unit-test

These require a device (or a specific test harness) and aren't amenable to `@Test`:

- **Siri phrase recognition.** Speech recognition is integrated with the OS. Use Xcode's App Shortcuts Preview tool (macOS Sonoma + Xcode 15+) to exercise phrase matching without voice; for voice, test on a real device.
- **Spotlight ranking.** The system's semantic similarity index runs opaquely. Donate entities, query Spotlight, and inspect — there's no programmatic ranking API.
- **Snippet rendering as a system overlay.** Unit tests can verify the view is constructed; only the snippet host shows the overlay visually.
- **Apple Intelligence invocations.** Most assistant-schema surfaces roll out gradually. Test via the Shortcuts app (filter by "AssistantSchemas") until Siri consumer surfaces ship.
- **Visual Intelligence pixel-buffer matching.** Requires the camera / screenshot context. Stub `IntentValueQuery.values(for:)` at the boundary and unit-test the stubbed function; integration-test on device.
- **Widget + control redraw cycles.** Test the intent's mutation; the widget's visual refresh needs a device or the widget simulator.

## Integration-testing through Shortcuts

The Shortcuts app itself is the best zero-code integration harness:

1. Build + run on a device or simulator.
2. Open Shortcuts → tap `+` → search for your intent.
3. Configure parameters, run.
4. Verify dialog, return value, snippet.

For assistant-schema intents, filter Shortcuts' library by "AssistantSchemas" to see only the schema-conforming subset.

For visual intelligence, invoke the system's Visual Intelligence flow on a real device and confirm your `IntentValueQuery` returns results.

## Fixtures and test data

Keep a `Fixtures` namespace with canned entities:

```swift
enum Fixtures {
    static let articleA = ArticleEntity(
        id: UUID(),
        title: "Dive into App Intents",
        summary: "..."
    )
    static let articleB = ArticleEntity(
        id: UUID(),
        title: "Getting Started with SwiftData",
        summary: "..."
    )
}
```

Using fresh UUIDs per test run is fine for in-memory mocks. Use stable UUIDs (hard-coded in source) when a test depends on ordering or when multiple tests share a mock store.

## Running tests

Tests run on the host platform (macOS) unless you specifically need device-side APIs. App Intents' core protocols, macros, and property wrappers work under macOS test builds, so most of the unit-test surface is host-testable.

For device-only features (Spotlight APIs, `UIApplication`-dependent flows), gate tests with `@available(iOS ..., *)` and use a physical device in CI.
