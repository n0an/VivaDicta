# What's New In-App Screen

## How It Works

The What's New screen is a sheet that appears once per app version after an update. It compares the stored `lastSeenWhatsNewVersion` (in `UserDefaultsStorage.appPrivate`) with `CFBundleShortVersionString`. If they differ and content exists for that version, the sheet is presented 800ms after MainView appears.

Fresh installs skip it — the version is stamped when onboarding completes.

## Files

```
Views/WhatsNew/
├── WhatsNewContent.swift       — Data models + WhatsNewCatalog
├── WhatsNewFeatureRow.swift    — Feature row component
└── WhatsNewView.swift          — Main sheet view
```

Integration points:
- `Shared/UserDefaultsStorage.swift` — `lastSeenWhatsNewVersion` key
- `Views/MainView.swift` — sheet presentation + version check in `handleOnAppear()`
- `VivaDictaApp.swift` — stamps version on onboarding completion

## Adding a New Version

**One file to edit:** `WhatsNewContent.swift`

1. Add a new static property in `WhatsNewCatalog`, preceded by a **date comment**:

```swift
// YYYY-MM-DD
private static let release_X_Y = WhatsNewRelease(
    id: "X.Y",
    headline: "What's New in VivaDicta X.Y.Z",   // user-facing: ALWAYS use the full X.Y.Z form (e.g. "VivaDicta 3.3.0", not "3.3")
    features: [
        WhatsNewFeature(
            icon: "sf.symbol.name",      // SF Symbol
            iconColors: [.blue, .cyan],   // gradient for the icon circle
            title: "Feature Name",
            description: "Short description of the feature."
        ),
    ]
)
```

2. Register it in the `releases` dictionary:

```swift
private static let releases: [String: WhatsNewRelease] = [
    "X.Y": release_X_Y,
    // ... existing entries
]
```

### The date comment

Each release property is preceded by a single-line ISO date comment marking when the entry was written:

```swift
// 2026-08-09
private static let release_3_8 = WhatsNewRelease(
    id: "3.8",
    ...
)
```

`WhatsNewRelease` carries no date field, and the `releases` dictionary is keyed by version, so the file has no other record of *when* a release shipped. The comment supplies it at a glance when scrolling a catalog that now spans a dozen versions.

Rules:
- ISO `YYYY-MM-DD` only - no prose, no "shipped on", no month names.
- Sits directly above `private static let release_X_Y`, at the same indentation.
- Use the release-prep date (the day the entry is authored), not the eventual App Store approval date.
- Newest entry goes at the top of the file, so the dates read newest-first downward.
- Older entries predate the convention and have no comment. Do **not** backfill them - it would be guesswork, and a wrong date is worse than none.

## Feature Row Guidelines

- **icon**: SF Symbol that visually represents the feature
- **iconColors**: Two colors for a `LinearGradient` (topLeading → bottomTrailing)
- **title**: Short, 2-4 words (displayed as `.headline`)
- **description**: One sentence, ~15-20 words max (displayed as `.subheadline`, secondary color)
- Keep the list to 5-8 features — group small changes under a "Quality of Life" item

## Version Matching

The catalog matches on **major.minor** only. `2.1.0`, `2.1.1`, `2.1.2` all resolve to `"2.1"`.
- Users see What's New once when upgrading to X.Y.0
- Patch releases don't re-trigger it

## Testing

Temporarily add in `VivaDictaApp.swift` `init()`:

```swift
// DEBUG: REMOVE BEFORE RELEASE
UserDefaultsStorage.appPrivate.set("1.9.0", forKey: UserDefaultsStorage.Keys.lastSeenWhatsNewVersion)
```

**IMPORTANT**: Remove before release build.
