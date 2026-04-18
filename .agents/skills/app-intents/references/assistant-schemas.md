# Assistant schemas (Apple Intelligence)

Regular `AppEntity` / `AppIntent` let Siri understand *your* concepts. **Assistant schemas** let Siri understand your concepts *in terms of shared cross-app categories* - journal entries, mail messages, browser bookmarks, photo assets, spreadsheet cells. This is the layer that lets Apple Intelligence compose across apps ("take the last three photos I shared in Messages and draft a journal entry about them").

Requires iOS 18.2+ for most schemas; some journaling, mail, and spreadsheet schemas require 18.4+. Availability of the *features that consume* these schemas is rolling out slowly - adopting the schema makes your data eligible, it does not guarantee it will be used.

## App Intent Domains

Schemas are grouped into **domains** - one per app category Apple has pre-trained Siri/Apple Intelligence on. Each domain ships with `create`, `open`, `update`, `delete`, and `search` schema variants, with ~100 pre-trained intents across the lineup.

Domains shipped so far:

- `.books` - read position, annotations, library
- `.browser` - tabs, bookmarks, history
- `.camera` - capture flows
- `.files` - document operations
- `.journal` - entry composition and search
- `.mail` - compose, reply, search
- `.photos` - assets, albums, persons
- `.presentations` - slides, decks
- `.spreadsheets` - cells, ranges, templates
- `.system` - search (`.system.search`), share, print
- `.systemSearch` - search queries and suggestions
- `.visualIntelligence` - semantic content search
- (Others roll out in later iOS releases.)

Adopt the most specific domain that matches your app. A reading app uses `.books`; a markdown-notes app uses `.journal`; a scanner app uses `.files` + `.photos`.

## Adopting a schema

Use `@AssistantEntity(schema:)` on an entity type:

```swift
import AppIntents
import CoreLocation

@AssistantEntity(schema: .journal.entry)
struct JournalEntryEntity: IndexedEntity {
    var id: UUID

    // These names and types are prescribed by the schema - you cannot rename them
    var title: String?
    var message: AttributedString?
    var mediaItems: [IntentFile]
    var entryDate: Date?
    var location: CLPlacemark?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Journal entry"
    static let defaultQuery = JournalEntryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title ?? "Untitled")")
    }
}
```

Key consequences:

- **Prescribed property names and types.** `message` must be `AttributedString?`, not `String`. `entryDate` is `Date?`, optional. `location` is `CLPlacemark?`. The macro validates these and emits opaque compiler errors if you deviate.
- **More optionality than you'd expect.** Many schema-required fields are optional even when your real data always has them. Provide sensible fallbacks in initializers or display representations.
- **Import `CoreLocation`** for any schema that carries location.

### A convenience initializer

Because the macro rewrites stored properties to private `_entityProperty`-wrapped versions, the synthesized init is ugly. Provide your own `init` for internal use:

```swift
init(id: UUID, title: String?, body: String, createdAt: Date?, location: CLPlacemark? = nil) {
    self.id = id
    self.title = title
    self.message = AttributedString(body)
    self.mediaItems = []
    self.entryDate = createdAt
    self.location = location
}
```

## Adopting intent schemas

Symmetric to entities. Use `@AssistantIntent(schema:)` or the newer `@AppIntent(schema:)` form:

```swift
@AppIntent(schema: .photos.createAssets)
struct CreateAssetsIntent: AppIntent {
    var files: [IntentFile]

    @Dependency
    var library: MediaLibrary

    @MainActor
    func perform() async throws -> some ReturnsValue<[AssetEntity]> {
        guard !files.isEmpty else { throw IntentError.noEntity }

        var result: [AssetEntity] = []
        for file in files {
            let asset = try await library.createAsset(from: file)
            result.append(asset.entity)
        }
        return .result(value: result)
    }
}

@AppIntent(schema: .photos.openAsset)
struct OpenAssetIntent: OpenIntent {
    var target: AssetEntity
    @Dependency var library: MediaLibrary
    @Dependency var navigation: NavigationManager

    @MainActor
    func perform() async throws -> some IntentResult {
        let assets = library.assets(for: [target.id])
        guard let asset = assets.first else { throw IntentError.noEntity }
        navigation.openAsset(asset)
        return .result()
    }
}

@AppIntent(schema: .photos.updateAsset)
struct UpdateAssetIntent: AppIntent {
    var target: [AssetEntity]
    var name: String?
    var isHidden: Bool?
    var isFavorite: Bool?

    @Dependency var library: MediaLibrary

    func perform() async throws -> some IntentResult {
        let assets = await library.assets(for: target.map(\.id))
        for asset in assets {
            if let isHidden   { try await asset.setIsHidden(isHidden) }
            if let isFavorite { try await asset.setIsFavorite(isFavorite) }
        }
        return .result()
    }
}

@AppIntent(schema: .photos.deleteAssets)
struct DeleteAssetsIntent: DeleteIntent {
    static let openAppWhenRun = true

    var entities: [AssetEntity]

    @Dependency var library: MediaLibrary

    @MainActor
    func perform() async throws -> some IntentResult {
        let ids = entities.map(\.id)
        let assets = library.assets(for: ids)
        try await library.deleteAssets(assets)
        return .result()
    }
}

@AppIntent(schema: .photos.search)
struct SearchAssetsIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]

    var criteria: StringSearchCriteria

    @Dependency var navigation: NavigationManager

    @MainActor
    func perform() async throws -> some IntentResult {
        navigation.openSearch(with: criteria.term)
        return .result()
    }
}
```

The schema dictates:

- Which parameters are required/optional and what their names must be.
- What the intent must return (often an entity of the matching schema type).
- Which intent subprotocol to conform to (`OpenIntent` for `.photos.openAsset`, `DeleteIntent` for `.photos.deleteAssets`, `ShowInAppSearchResultsIntent` for `.photos.search`, ...).

`@AppIntent(schema:)` is the modern syntax; `@AssistantIntent(schema:)` works too and is equivalent. New code should use `@AppIntent(schema:)`.

## Testing schema intents before Apple Intelligence reaches users

Assistant-schema intents light up in Siri / Apple Intelligence gradually as Apple rolls each schema's consumer out. Before that happens, test them **inside the Shortcuts app**:

- In Shortcuts' library, filter by **AssistantSchemas** to see only schema-conforming intents.
- Configure and run them manually like any other action; the execution path is the same as when Siri invokes them.
- Once the consuming Apple Intelligence surface ships, no code changes are needed - the same intents automatically become Siri-addressable.

This is the intended validation path while schemas are still rolling out.

## Xcode schema code snippets

Xcode 16+ ships code snippets for every schema. Type the domain name (`journal`, `photos`, `mail`) in the editor; completion offers pre-filled skeletons for each schema's intent, entity, and enum - the names and types are already correct, so you avoid the macro's cryptic "field doesn't match schema" errors.

Use the snippets for first-time adoption. Hand-writing a schema type from the API docs alone is error-prone because the macro rejects small deviations without helpful diagnostics.

### Browsing available schemas

Type a domain name followed by a dot in the macro argument, and Xcode completion lists every schema in that domain:

```swift
@AppIntent(schema: .photos.|)     // Xcode shows .asset, .album, .createAssets, .openAsset, ...
@AppEntity(schema: .journal.|)    // Xcode shows .entry, .entryLocation, ...
```

Faster than grepping Apple's documentation. Use completion as the authoritative list; Apple adds schemas in minor OS releases without always updating the doc-set indexing.

## Schema-adopted enums

Enums can also declare schema adoption. The macro enforces allowed case names:

```swift
@AppEnum(schema: .photos.assetType)
enum AssetType: String, AppEnum {
    case photo
    case video

    static let caseDisplayRepresentations: [AssetType: DisplayRepresentation] = [
        .photo: "Photo",
        .video: "Video"
    ]
}
```

The `.photos.assetType` schema requires exactly `.photo` and `.video` cases. Adding a `.livePhoto` case without schema support won't compile; you'd need a separate non-schema enum.

## Schema-adopted entities

Using the entity macro in combination with a photo schema:

```swift
@AppEntity(schema: .photos.asset)
struct AssetEntity: IndexedEntity {

    static let defaultQuery = AssetQuery()

    let id: String
    let asset: Asset

    @Property(title: "Title")
    var title: String?

    var creationDate: Date?
    var location: CLPlacemark?
    var assetType: AssetType?
    var isFavorite: Bool
    var isHidden: Bool
    var hasSuggestedEdits: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: title.map { "\($0)" } ?? "Unknown",
            subtitle: assetType?.localizedStringResource ?? "Photo"
        )
    }
}
```

The schema enforces field names (`creationDate`, `location`, `isFavorite`, etc.) and their types. The macro emits compilation errors if you rename or retype.

## Schema-specific intent protocols

Several intent subprotocols target a specific schema behavior:

### `DeleteIntent`

```swift
@AppIntent(schema: .photos.deleteAssets)
struct DeleteAssetsIntent: DeleteIntent {
    static let openAppWhenRun = true
    var entities: [AssetEntity]
    ...
}
```

Exposes the intent as a system-standard delete action. The system may prompt for confirmation automatically before invoking `perform()`.

### `ShowInAppSearchResultsIntent`

```swift
@AppIntent(schema: .photos.search)
struct SearchAssetsIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]
    var criteria: StringSearchCriteria
    ...
}
```

Routes a system search query into the app's in-app search UI. Siri / Spotlight / visual intelligence can invoke this so results surface inside the app's native search rather than as external cards.

`.system.search` is the generic version of this schema, usable by any app type. Photo and mail apps use the domain-specific variants (`.photos.search`, `.mail.search`). iOS 18+.

## Apple Intelligence through Shortcuts: the Use Model action

iOS 26+. Shortcuts ships a **Use Model** action that invokes on-device, Private Cloud Compute, or ChatGPT models, with App Entities as input and output:

- **App entity input** - the Shortcuts runtime serializes the entity to JSON (its display representation, type name, and exposed `@Property` values) and passes that to the model as context.
- **Output** - the model can emit text, dictionaries, booleans, or an App Entity of a type you declare. Downstream intents receive it as a typed value.
- **Follow-up turns** - the action supports multi-turn conversation, useful for assistants-over-app-data flows.

For intent authors, two implications:

### Accept `AttributedString`, not `String`, for text parameters

When an intent's text parameter may receive model output, declare it as `AttributedString`:

```swift
@Parameter(title: "Body")
var body: AttributedString
```

Models increasingly generate rich text (bold, italic, lists, tables). `String` parameters lose formatting; `AttributedString` preserves it losslessly. Internally, drop to `String(body.characters[...])` when you need plain text.

### Expose the fields the model should see via `@Property`

The JSON the Use Model action sends to the model is built from your entity's `@Property`-exposed fields (plus `typeDisplayRepresentation` and `displayRepresentation`). Fields not marked `@Property` are invisible to the model. Audit your entities for anything a user-friendly model response would need.

This is a direct, low-ceremony integration point with Apple Intelligence that requires no schema adoption - any `AppIntent` with well-shaped entities participates automatically.

## Visual intelligence: `IntentValueQuery` + `@UnionValue`

On iOS 18.4+, the system's **visual intelligence** feature lets a user circle an object (in the camera view or on screen) to search across apps. An app participates by implementing an `IntentValueQuery` that takes a `SemanticContentDescriptor` (carrying a pixel buffer) and returns matching entities.

Declare the set of result kinds with `@UnionValue`:

```swift
#if canImport(VisualIntelligence)
import AppIntents
import VideoToolbox
import VisualIntelligence

@UnionValue
enum VisualSearchResult {
    case landmark(LandmarkEntity)
    case collection(CollectionEntity)
}

struct LandmarkIntentValueQuery: IntentValueQuery {

    @Dependency var modelData: ModelData

    func values(for input: SemanticContentDescriptor) async throws -> [VisualSearchResult] {

        guard let pixelBuffer: CVReadOnlyPixelBuffer = input.pixelBuffer else {
            return []
        }

        let landmarks = try await modelData.search(matching: pixelBuffer)
        return landmarks
    }
}
#endif
```

`@UnionValue` lets one query return multiple entity types; the system displays them as a unified result list. Use one case per entity type.

To route the user back into the app after they pick a result, pair the query with a schema-adopted intent:

```swift
#if canImport(VisualIntelligence)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct ShowSearchResultsIntent {
    static let title: LocalizedStringResource = "Image Search"
    var semanticContent: SemanticContentDescriptor
}

extension ShowSearchResultsIntent: TargetContentProvidingIntent {}
#endif
```

Guard the whole visual-intelligence surface with `#if canImport(VisualIntelligence)` - the framework is iOS-only and relatively new.

## Making onscreen content available to Siri: `userActivity(_:element:)`

When an entity is visible in your UI, Siri / Apple Intelligence can refer to it ("what can I do with this photo?") if the app declares an `NSUserActivity` that links the visible view to the entity.

```swift
import SwiftUI

struct AssetDetailView: View {
    let asset: Asset

    var body: some View {
        MediaView(image: asset.image)
            .userActivity(
                "com.example.MyApp.ViewingPhoto",
                element: asset.entity
            ) { element, activity in
                activity.title = "Viewing a photo"
                activity.appEntityIdentifier = EntityIdentifier(for: element)
            }
    }
}
```

Two required parts:

- `element:` - the `AppEntity` instance the view represents.
- `activity.appEntityIdentifier = EntityIdentifier(for: element)` - this is what lets the system correlate "the thing on screen" with a specific entity your app understands.

For Siri to actually forward the entity's *content* (not just reference it), the entity must also conform to `Transferable` (see `entities.md`). Text, image, and PDF representations are the most commonly useful.

A typical setup:

1. Declare the entity with `@AppEntity(schema:)` or plain `AppEntity`.
2. Conform it to `Transferable` for exportable content.
3. Register an onscreen activity with `.userActivity(_:element:)` when the view is visible.

With all three in place, Siri can answer "what is this?", forward the content to a third-party service the user taps, or use it as input to another intent - all driven by context rather than explicit commands.

## Available schemas (representative)

Categories (not exhaustive):

- `.books.*` - book, audiobook, library
- `.browser.*` - bookmark, window, tab
- `.files.*` - file
- `.journal.*` - entry, entryLocation, createEntry, updateEntry, searchEntries
- `.mail.*` - message, account, composition
- `.photos.*` - asset, assetType, album, person, createAssets, openAsset, updateAsset, deleteAssets, search
- `.presentations.*` - slide deck, slide
- `.spreadsheets.*` - sheet, cell, range, template
- `.systemSearch.*` - search query, search suggestion
- `.visualIntelligence.*` - semanticContentSearch (for visual intelligence integration)

Xcode 16+ ships code snippets. Type `journal` or `mail` into the editor and the completion menu offers skeletons for each schema's intents and entities; this is by far the fastest way to adopt a schema correctly given how strict the macro is.

## What adoption gets you

In principle:

- Your data participates in system searches ("find the note where I mentioned Berlin").
- Cross-app composition ("take this journal entry and share it in Mail").
- Siri understands domain verbs ("append this to my last journal entry") without you wiring each phrase.

In practice, as of early 2026 the feature surfaces consuming assistant schemas are rolling out unevenly. Adopt where the schema closely matches your domain, but treat actual behavior as a moving target - verify on a current iOS release rather than on the WWDC24 announcement.

## When NOT to adopt

- Your data is genuinely novel and doesn't fit any schema. Don't bend your model to match; stick with plain `AppEntity`.
- The schema forces losing fidelity (e.g., you have rich markdown and the schema insists on `AttributedString` which loses your extensions). Weigh the integration benefit against the modeling cost.
- You're still on iOS 17 or earlier - assistant schemas require 18.2+.

## Versioning caveat

Xcode embeds the schema version ("journal entry 1.0.0") in the macro-expanded code. Schemas are expected to evolve - Apple chose macros precisely so they can add fields without breaking existing adopters. Treat schema adoption as you would any platform API: rev your minimum deployment target when you need newer schema features, and expect some churn at first.

## Co-existence

You can have both a plain `AppEntity` and a schema-adopted entity in the same app. Some flows want the raw type; some want the schema-shaped one. Map between them where needed rather than trying to make one entity wear both hats.
