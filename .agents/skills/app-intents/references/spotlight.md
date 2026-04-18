# Spotlight indexing

Spotlight surfaces app entities in the system search UI and routes taps back to an `OpenIntent`. Setup is three small steps.

## 1. Conform to `IndexedEntity`

`IndexedEntity` is a subprotocol of `AppEntity` that adds Spotlight behavior. No extra required members - the entity's `displayRepresentation` is used to build the Spotlight card.

```swift
import AppIntents
import CoreSpotlight

struct ArticleEntity: IndexedEntity {
    var id: UUID
    var title: String
    var summary: String
    var publishedAt: Date
    var thumbnailURL: URL?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: "doc.text"))
    }
}
```

## 2. Send entities to `CSSearchableIndex`

Indexing is async and happens off the UI. Hand your entities to `CSSearchableIndex.default().indexAppEntities(_:)`.

```swift
import CoreSpotlight

guard CSSearchableIndex.isIndexingAvailable() else {
    return
}
try await CSSearchableIndex.default().indexAppEntities(entities)
```

`isIndexingAvailable()` returns `false` on platforms / configurations where Spotlight indexing isn't supported (some watchOS setups, disabled-by-user). Guarding avoids spurious error logs.

That's the whole API. You pass `IndexedEntity` instances; the system extracts the display representation, attribute set, and id.

## 3. Decide when to index

There's no one right answer - choose based on how changeable your content is.

### Full reindex on view appearance

Simple, and fine for small datasets (a few hundred entries):

```swift
struct ArticleList: View {
    @Query private var articles: [Article]

    var body: some View {
        List(articles) { article in
            NavigationLink(article.title, value: article)
        }
        .task(indexAll)
    }

    @Sendable func indexAll() async {
        try? await CSSearchableIndex.default().indexAppEntities(articles.map(\.entity))
    }
}
```

Pros: correctness-first, no change tracking.
Cons: wasted work for large datasets or rarely-changing content.

### Per-entity reindex on change

Index one item when a specific field changes. Use with a debounced task so you don't reindex on every keystroke:

```swift
struct ArticleEditor: View {
    @Bindable var article: Article
    @State private var indexingTask: Task<Void, Error>?

    var body: some View {
        Form {
            TextField("Title", text: $article.title)
            TextField("Body", text: $article.body, axis: .vertical)
        }
        .onChange(of: article.title,  scheduleIndex)
        .onChange(of: article.body,   scheduleIndex)
    }

    func scheduleIndex() {
        indexingTask?.cancel()
        indexingTask = Task {
            try await Task.sleep(for: .seconds(1))
            try await CSSearchableIndex.default().indexAppEntities([article.entity])
        }
    }
}
```

Cancelling the previous task before sleeping means typing fast produces one index call, not twenty.

### Bulk index at startup

If your content is effectively static (curated catalogue, preset library), index everything once in `App.init()` or on first launch and don't bother with per-change tracking.

Apple's explicit recommendation (WWDC24) is to perform the initial index inside `App.init()` - this guarantees indexing runs before any intent, widget, or Siri invocation can surface a stale or missing entity. For mutable content, pair the startup index with per-change updates (see the previous two strategies).

## Mapping properties to indexing keys: `@ComputedProperty(indexingKey:)`

If you've already declared entity computed properties with `@ComputedProperty` (see `entities.md`), you can map them directly to Spotlight attribute-set keys without writing any `attributeSet` code:

```swift
struct LandmarkEntity: IndexedEntity {
    @ComputedProperty(indexingKey: \.displayName)
    var name: String { landmark.name }

    @ComputedProperty(indexingKey: \.contentDescription)
    var description: String { landmark.description }

    @ComputedProperty(
        customIndexingKey: CSCustomAttributeKey(
            keyName: "com_example_LandmarkEntity_continent"
        )!
    )
    var continent: String { landmark.continent }
}
```

Standard indexing keys (`\.displayName`, `\.contentDescription`, `\.keywords`, `\.addedDate`, ...) correspond to fields on `CSSearchableItemAttributeSet`. Custom keys are for domain-specific attributes that don't fit any standard; declare them once via `CSCustomAttributeKey(keyName:)` and reference them consistently.

This is the leanest way to feed Spotlight for most entities. Only drop into an explicit `attributeSet` computed property when you need fields that can't be mapped from a single computed property (e.g., an image URL constructed from multiple inputs).

## Associating Spotlight items with entities: `associateAppEntity`

Some apps already have a mature Spotlight indexing pipeline built around `CSSearchableItem` - a non-entity `Trail` or `Document` type with a carefully-tuned `CSSearchableItemAttributeSet`. Rather than rewriting indexing to go through `IndexedEntity`, associate the existing `CSSearchableItem` with the matching `AppEntity`:

```swift
import CoreSpotlight

func updateSpotlightIndex() async {
    guard CSSearchableIndex.isIndexingAvailable() else { return }

    let searchableItems = trails.map { trail in
        let item = CSSearchableItem(
            uniqueIdentifier: String(trail.id),
            domainIdentifier: nil,
            attributeSet: trail.searchableAttributes
        )

        let isFavorite = favoritesCollection.members.contains(trail.id)
        let priority = isFavorite ? 10 : 1
        let entity = TrailEntity(trail: trail)

        // Link the Spotlight item to the corresponding AppEntity.
        // Must happen BEFORE the item is added to the index.
        item.associateAppEntity(entity, priority: priority)
        return item
    }

    try? await CSSearchableIndex.default().indexSearchableItems(searchableItems)
}
```

Why this matters:

- The app's existing `CSSearchableItem` pipeline keeps working unchanged.
- When the user taps a Spotlight result, the system knows an `AppEntity` is associated with it, and routes the tap through the matching `OpenIntent` (see `open-and-snippet-intents.md`) instead of just opening the app.
- `priority:` nudges ranking - favorite / pinned items get a larger number and surface earlier.

Pick one approach per entity: either `indexAppEntities([entity])` (for new apps and simple cases), or `indexSearchableItems([item])` with `item.associateAppEntity(entity, priority:)` (when you already have a detailed attribute-set pipeline).

## Enriching the Spotlight card with `attributeSet`

Override `var attributeSet: CSSearchableItemAttributeSet` on your `IndexedEntity` to add content beyond the default display representation. Start from `defaultAttributeSet`, don't build one from scratch:

```swift
import CoreSpotlight

struct ArticleEntity: IndexedEntity {
    var id: UUID
    var title: String
    var summary: String
    var publishedAt: Date
    var thumbnailURL: URL?

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Article"
    static let defaultQuery = ArticleEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: "doc.text"))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.contentDescription = summary
        set.addedDate = publishedAt
        set.thumbnailURL = thumbnailURL
        set.keywords = ["article", "reading"]
        return set
    }
}
```

Useful `CSSearchableItemAttributeSet` fields (there are many more - autocomplete is your friend):

- `contentDescription` - body text Spotlight searches over.
- `addedDate`, `contentCreationDate`, `contentModificationDate`, `dueDate`, `startDate`, `completionDate`.
- `thumbnailURL`, `thumbnailData`.
- `keywords` - array of strings weighted higher than body text.
- `authors`, `contributors` (`CSPerson` array).
- `artist`, `album` (for audio).
- `latitude`, `longitude`, `namedLocation` (for geotagged content).

The system's ranking algorithm is opaque; more signal generally helps. Don't abuse semantically-loaded fields (`dueDate`, `startDate`) for unrelated data - Siri may interpret them literally ("what's due soon?" surfacing unrelated items).

## Tap-to-open

Tapping a Spotlight result lands in your app via a matching `OpenIntent` (see `open-and-snippet-intents.md`). The match is: result entity type → `OpenIntent` whose `target` parameter is that entity type. No extra registration.

## Cleaning up

On app uninstall the system removes your index automatically. If an item is deleted in-app:

```swift
try await CSSearchableIndex.default().deleteAppEntities(
    identifiedBy: [deletedID],
    ofType: ArticleEntity.self
)
```

## Debugging

In Simulator's Developer menu there are two toggles worth knowing:

- **Display Recent Shortcuts** - shows cached shortcut suggestions, confirms they are reaching the system.
- **Display Donations on Lock Screen** - shows intent donations, helpful when wiring up predictive shortcuts.

Reliability of Spotlight indexing in Simulator is noticeably worse than on device; if search "doesn't find anything", try the device before assuming a code bug.
