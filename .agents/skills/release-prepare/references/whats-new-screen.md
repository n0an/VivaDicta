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

1. Add a new static property in `WhatsNewCatalog`:

```swift
private static let release_X_Y = WhatsNewRelease(
    id: "X.Y",
    headline: "What's New in VivaDicta X.Y",
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
