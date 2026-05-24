# ADR-001: Adopt incremental modular architecture migration

**Date:** 2026-05-24
**Status:** Accepted

## Context

VivaDicta has grown from a single-screen voice-to-text app into a multi-target product (iOS app, keyboard extension, widget + Live Activity, share extension, action extension) with a companion macOS app sharing CloudKit storage. The codebase currently:

- Has a 4,030-line `AIService` god class orchestrating 16 LLM providers, OAuth flows, SSE streaming, mode management, and Apple Foundation Model integration.
- Mixes app target organization (`Views/`, `Services/`) with adapter modules already extracted to SwiftPM (`Modules/Networking/`, `Modules/OAuth/`, etc.).
- Has approximately 60% coverage of protocol-based DI seams across the modular shell, and approximately 0% in the app target proper.
- Uses `AppState` as a mutable service locator (`var x: Service!`).

This makes testing painful: view models and orchestration services can't be unit-tested without spinning up the full app, and adding a new AI provider requires editing the `AIService` god class.

## Decision

Adopt an incremental migration toward a modular, protocol-driven architecture, ordered by ROI and risk. The full plan lives in `llmtemp/architecture-migration-plan-v2-2026-05-24.md` and is summarized as:

- **Phase 0:** Codify conventions in-repo (this ADR + `architecture-conventions.md`). ✅ Done.
- **Phase 1b:** Protocol seams for the remaining concrete services (`TranscriptionManager`, `PresetSyncService`, `ModelDownloadManager`).
- **Phase 2:** Decompose `AIService` into per-provider `AIProvider` conformances + a thin coordinator. The single highest-leverage refactor remaining.
- **Phase 3:** Create a `VivaDictaDomain` package with pure value types and ports.
- **Phase 4:** Extract the first feature package (`RecordFeature`) as a template.
- **Phases 6-7:** Remaining feature packages + Composition Root refactor.
- **Phases 5 (Decorators) and 8 (Persistence isolation): skip** unless a concrete need emerges. Decorators duplicate concerns already centralized in `NetworkClient` / `NetworkRetry`; persistence isolation carries CloudKit schema risk that outweighs the testability benefit.

The migration is incremental, behavior-preserving, and explicitly stop-anywhere. Every phase boundary leaves the codebase strictly better than before.

## Consequences

### Easier

- **Adding a new AI provider** becomes "write an `AIProvider` conformance, register it." No edits to existing provider code.
- **Unit-testing view models** becomes possible once their dependencies are protocols with public mocks.
- **Onboarding new collaborators** is easier with explicit module boundaries and the dependency rule documented.
- **Reasoning about coupling** is easier - `swift build` enforces the layered dependency rule.

### Harder

- **More files, more SwiftPM packages.** Navigating the codebase requires understanding the module hierarchy.
- **More wiring in Composition Root.** Constructing the dependency graph is explicit instead of implicit.
- **Phase 2 (AIService decomposition) is 4-6 weeks of part-time work.** That's a substantial commitment for a solo developer.
- **Multi-target migrations are tricky.** Each phase that touches code shared with the keyboard / widget / extensions has to verify all 5 targets still build and run.

### Follow-up implied

- Each phase ships as one or more PRs, not a big-bang refactor.
- New ADRs accumulate in `documentation/adr/` as substantive structural decisions arise.
- `documentation/Module-Architecture.html` is kept current.
- After Phase 4 lands, a `documentation/feature-package-template.md` documents the feature-extraction pattern for Phase 6.

### Explicitly not addressed

- **Persistence isolation (Phase 8).** SwiftData models stay coupled to the persistence framework. Domain types in Phase 3 are parallel to (not replacements for) `Transcription` / `CustomRewritePreset` SwiftData entities.
- **Decorator pattern (Phase 5).** Cross-cutting concerns (logging, retry, status validation) stay centralized in their respective services rather than as decorator wrappers.
- **TCA or other architectural alternatives.** This decision commits to the MVVM + Services + protocols pattern.
- **`VivaDictaMac` synchronization strategy.** The companion macOS app's relationship to the new `VivaDictaDomain` package is deferred until Phase 3 actually lands; at that point a separate ADR will pick between vendoring, git submodules, or a separate SPM repository.

## Alternatives considered

1. **Full rewrite (e.g., TCA migration).** Rejected: too costly for an indie app, and the current MVVM + Services pattern works - it just needs cleaner seams.
2. **Big-bang refactor.** Rejected: contradicts the stop-anywhere principle and would put the app in a half-broken state for weeks.
3. **Do nothing, keep current architecture.** Rejected: the testing pain is real and growing; `AIService` will only get larger as more providers are added.
4. **Skip Phase 3 (VivaDictaDomain).** Deferred but not rejected. If after Phase 2 the testability win is good enough without pure domain types, skip Phase 3.

## References

- Migration plan: `llmtemp/architecture-migration-plan-v2-2026-05-24.md`
- Current architecture diagram: `documentation/Module-Architecture.html`
- Conventions: `documentation/architecture-conventions.md`
- Predecessor (superseded) plan: `llmtemp/caio-architecture-migration-plan-2026-05-24.md`
