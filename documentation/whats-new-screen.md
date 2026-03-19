# What's New Screen — Developer Guide

## How It Works

The What's New screen is a sheet that appears once per app version after an update. It compares the stored `lastSeenWhatsNewVersion` (in `UserDefaults.standard`) with `CFBundleShortVersionString`. If they differ and content exists for that version, the sheet is presented 800ms after MainView appears.

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

### Step 1 — Add the release content

Add a new static property at the bottom of `WhatsNewCatalog`:

```swift
private static let release_2_1 = WhatsNewRelease(
    id: "2.1",
    headline: "What's New in VivaDicta 2.1",
    features: [
        WhatsNewFeature(
            icon: "sf.symbol.name",      // SF Symbol
            iconColors: [.blue, .cyan],   // gradient for the icon circle
            title: "Feature Name",
            description: "Short description of the feature."
        ),
        // ... more features (aim for 5-8)
    ]
)
```

### Step 2 — Register it in the catalog

Add the entry to the `releases` dictionary:

```swift
private static let releases: [String: WhatsNewRelease] = [
    "2.0": release_2_0,
    "2.1": release_2_1    // <-- add this line
]
```

That's it. No other files need changes. The version check in MainView handles the rest automatically.

## How Version Matching Works

The catalog matches on **major.minor** only. So version `2.1.0`, `2.1.1`, `2.1.2` all resolve to the `"2.1"` catalog entry. This means:
- Users see What's New once when upgrading to 2.1.0
- Patch releases (2.1.1, 2.1.2) don't re-trigger it
- If you want a patch release to show What's New, give it a new minor version instead

## Feature Row Guidelines

- **icon**: Use an SF Symbol that visually represents the feature
- **iconColors**: Two colors for a `LinearGradient` behind the icon (topLeading → bottomTrailing)
- **title**: Short, 2-4 words (displayed as `.headline`)
- **description**: One sentence, ~15-20 words max (displayed as `.subheadline`, secondary color)
- Keep the list to 5-8 features — group small changes under a "Quality of Life" item

## Testing During Development

To re-trigger the What's New sheet for testing, clear the stored version:

```swift
// In a debug action or via lldb:
UserDefaults.standard.removeObject(forKey: "lastSeenWhatsNewVersion")
```

Or set it to a different version:

```swift
UserDefaults.standard.set("1.9.0", forKey: "lastSeenWhatsNewVersion")
```

Then relaunch the app. The sheet will appear if `WhatsNewCatalog` has content for the current bundle version.

## Visual Design

The sheet reuses existing onboarding components:
- `OnboardingAppIcon(useSinebow: true)` — animated sinebow shader icon at the top
- Animated `MeshGradient` title text (same as onboarding welcome page)
- `WhatsNewFeatureRow` — gradient circle icon + headline + subheadline
- `OnboardingPrimaryButton` — "Continue" button pinned to the bottom with `.ultraThinMaterial` background
- Staggered fade-in animation for features (0.08s intervals)
- Sheet is non-dismissible (`.interactiveDismissDisabled()`) — user must tap Continue
