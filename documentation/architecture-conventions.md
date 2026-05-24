# Architecture Conventions

This document codifies the in-repo conventions every new module, service, and test must follow. It exists alongside `~/.claude/CLAUDE.md` (which targets AI tooling) - this file targets humans collaborating on the codebase.

For the broader migration plan these conventions support, see `llmtemp/architecture-migration-plan-v2-2026-05-24.md`.

## Naming

### Protocols

Use the plain noun (`<Name>`) - **never** the `-ing` suffix.

- ✅ `NetworkService`, `KeychainService`, `OAuthManager`, `TranscriptionService`, `AIProvider`
- ❌ `NetworkServicing`, `KeychainServicing`, `OAuthManaging`, `Transcribing`

### Concrete implementations

When a protocol has a single canonical production conformance, name it `Default<Name>`.

- ✅ `DefaultNetworkService`, `DefaultKeychainService`, `DefaultOAuthManager`
- When the impl has personality (backend-specific etc.), prefer descriptive over `Default`: `URLSessionAIProvider`, `OpenAIBackedAIProvider`, `AVFoundationAudioRecorder`.
- `Impl` suffix (`NetworkServiceImpl`) is acceptable but less Swift-idiomatic - it's a Java/C# carryover. Don't use it for new code.

This convention applies to **new** services. For existing aggregated impls (like `AIService`, which conforms to multiple protocols), keep the existing name until decomposition. The `Default<Name>` rule is for one-protocol-one-impl situations.

### Mocks

Always `Mock<Name>`. Lives in a parallel `<Module>Mocks` target.

- ✅ `MockNetworkService`, `MockOAuthManager`, `MockKeychainService`
- ❌ `<Name>Mock`, `Fake<Name>`, `Stub<Name>`

### Type-suffix naming (avoid generic `Manager`)

For new types, prefer a specific suffix that names the responsibility:

| Suffix | When to use | Example |
|---|---|---|
| `Service` | Provides functionality, often stateless or near-stateless | `KeychainService`, `AnalyticsService` |
| `Repository` / `Store` | Owns persistence + retrieval of one entity | `PresetRepository`, `TranscriptionStore` |
| `Coordinator` | Orchestrates flow between other components | `OnboardingCoordinator` |
| `Engine` | Stateful long-running processor | `TranscriptionEngine` |
| `Router` | Routes requests to the right handler | `URLRouter`, `DeepLinkRouter` |
| `Provider` | Produces values on demand | `LocationProvider`, `AIProvider` |
| `Player` | Plays / produces media | `HapticPlayer`, `AudioPlayer` |
| `Downloader` | Fetches resources | `ModelDownloader` |
| `Prompter` | Triggers user prompts | `RateAppPrompter` |
| `Scheduler` | Schedules deferred work | `BackgroundTaskScheduler` |
| `Manager` | **Only** when genuinely managing lifecycle of a system resource AND the responsibility is canonical enough that any alternative would obscure it | `FileManager`, `OAuthManager` (industry-standard) |

**Don't rename existing `*Manager` types as a sweep.** Convert opportunistically when you're already touching the file and a better name is obvious.

## Module organization

### Layered dependency rule

Inner-ring modules cannot import outer-ring modules. The rings are:

```
Layer 0 (core, no in-repo deps):
  TestUtilities, Networking, Keychain, Presets, TranscriptionCore,
  DesignSystem, AppGroup
  + future: VivaDictaDomain

Layer 1 (adapters - single concern: protocol + Default + Mock):
  OAuth, CloudTranscription, LocalTranscription
  + future: AIProviders/

Layer 2 (orchestrators - compose multiple adapters):
  TranscriptionKit
  + future: feature packages' Core targets

Layer 3 (features - UI + view models):
  + future: Features/RecordFeature, Features/LibraryFeature, etc.

Layer 4 (app):
  VivaDicta main target, extensions
```

A module in layer N can import only modules in layers `0..<N`. A new module's `Package.swift` must reflect this.

### `<Module>Mocks` target pattern

Every module that exposes a mockable protocol ships a parallel `<Module>Mocks` library:

```
Modules/OAuth/
├── Sources/
│   ├── OAuth/                  ← production: protocol + Default impl
│   └── OAuthMocks/             ← public: MockOAuthManager, etc.
└── Tests/
    └── OAuthTests/             ← imports both targets
```

- **`<Module>Mocks` imports `<Module>` + `TestUtilities`**, never the other way around.
- **Consumer tests** import `<Module>Mocks` (e.g., `VivaDictaTests` imports `NetworkingMocks`).
- **Production code never imports `*Mocks`.**

### Mock fidelity

Mocks must mirror production observable lifecycle. If `DefaultOAuthManager.signIn(...)` flips `isSignedIn(provider:)` to `true` on success, `MockOAuthManager.signIn(...)` must do the same. Otherwise tests stub behavior that diverges from production - a class of bug that's hard to spot.

The `MockOAuthManagerLifecycleTests` in `Modules/OAuth/Tests` exists specifically to lock this in.

## Testing

### Test type shape

Use Swift `struct` test types - never `final class` with `var x: T!` + `deinit` cleanup.

Swift Testing creates a fresh struct per `@Test`, so per-test isolation is automatic.

```swift
// ✅ Correct
struct OpenAITranscriptionServiceTests {
    @Test func successReturnsText() async throws {
        let networkService = MockNetworkService()
        networkService.stubUploadResponse = .success(...)
        let sut = makeSUT(networkService: networkService)
        let result = try await sut.transcribe(audioURL: ...)
        #expect(result.text == "hello")
    }
}

// ❌ XCTest carry-over - don't write new code like this
final class OpenAITranscriptionServiceTests {
    var sut: OpenAITranscriptionService!
    var networkService: MockNetworkService!
    init() { ... }
    deinit { sut = nil; networkService = nil }
}
```

### `sut` variable name

The variable holding the type under test is **always** `sut` (system under test).

- ✅ `let sut = DefaultNetworkService(session: session)`
- ❌ `let service = ...`, `let client = ...`, `let provider = ...`

Mocks keep their explicit names (`networkService`, `keychain`, `mockRepo`) - only the SUT is `sut`. Reading a test, this makes the line being exercised vs. the dependencies being stubbed visually distinct.

### Dependency variable naming

The variable holding an injected dependency should match the consumer's init parameter name.

- ✅ `let networkService = MockNetworkService()` (because consumer takes `init(networkService:)`)
- ❌ `let session = MockNetworkService()` (when the parameter is `networkService:`)

### Hoist `sut` to a property?

- **Hoist** to a `let sut: X` property + `init()` when the SUT config is **constant across all tests** in the file.
- **Construct per test** (often via a `makeSUT(...)` helper) when the SUT config **varies per test** (different API keys, different modes, etc.).

Both shapes use `sut` as the variable name. The choice is about where you build it.

## PR / commit hygiene

### One concern per PR

Don't bundle structural changes with feature work. Don't bundle naming conventions with bug fixes. Reviewers and `git bisect` both benefit from focused PRs.

### Commit messages

- Lead with what changed, not where.
- Explain *why* if the diff doesn't make it obvious.
- Don't include AI co-author attribution. Don't include "Generated with ... " footers.
- Don't reference other people's projects or codebases (open-source samples, tutorial repos, etc.) in PR descriptions or commit messages. If you learned a pattern from elsewhere, describe the pattern on its own merits as if the decision originated here.

### Architecture Decision Records (ADRs)

When a structural decision is made that future readers should understand, record it in `documentation/adr/`. Template lives at `documentation/adr/ADR-000-template.md` (TODO: write).

## Related documents

- `Module-Architecture.html` - current module dependency graph and testing seams (visual)
- `adr/ADR-001-modular-architecture.md` - decision to follow the modular pattern
- `../llmtemp/architecture-migration-plan-v2-2026-05-24.md` - in-progress migration plan
- `~/.claude/CLAUDE.md` (global, AI assistant) - the canonical source of these conventions for automated tooling
