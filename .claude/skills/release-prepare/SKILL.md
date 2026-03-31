---
name: release-prepare
description: Prepare a new VivaDicta release — version bump, What's New screen, App Store metadata, code sweep, and pre-submission checklist
---

# Release Prepare

Use this skill when preparing a new VivaDicta release for App Store submission.

## Related Skills

- `asc-release-flow` — drive the App Store Connect submission flow
- `asc-whats-new-writer` — generate App Store release notes
- `asc-metadata-sync` — sync and validate App Store metadata
- `asc-localize-metadata` — sync metadata across localizations (used for ASO, not actual translation)
- `asc-aso-audit` — run ASO audit on App Store metadata and surface keyword gaps

## Skill Flow

- Example queries:
  - "prepare release 2.2.0"
  - "let's ship a new version"
  - "release prep"

### Step 1 — Create release branch

```
git checkout -b release/X.Y.Z
```

### Step 2 — Bump version numbers

Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` across ALL targets:
- VivaDicta (main app) — Debug, Release, Profile configurations
- VivaDictaKeyboard
- VivaDictaWidget
- ShareExtension
- ActionExtension

Convention: version `X.Y.Z` uses build number `XY0Z` (e.g., 2.1.0 → 2101, 2.2.0 → 2201).

### Step 3 — Code sweep

Run a pre-release code sweep checking for:
- TODO/FIXME/HACK comments that need attention before release
- Hardcoded debug/test values (test API keys, localhost URLs, debug flags)
- `print()` statements that should use `Logger`
- Dangerous force unwraps
- Any leftover debug triggers (e.g., forced What's New screen)
- Build the project and check for warnings

### Step 4 — What's New in-app screen

Use `references/whats-new-screen.md` for the full guide on adding What's New content to the in-app screen.

### Step 5 — App Store What's New (release notes)

Write App Store release notes and save to Obsidian vault at:
`Projects/VivaDicta/what's new/whats-new-X.Y.Z.md`

**Format**: No frontmatter, no markdown header — plain text only, ready to copy-paste into App Store Connect.

**IMPORTANT**: App Store What's New (release notes) limit is **4,000 characters**. Always verify the character count.

**ASO strategy**: All localizations use English text — no actual translations. Different localizations may have different English text variations to target different keywords. This applies to description, what's new, keywords, and subtitle.

Source features from:
- Obsidian vault: `Projects/VivaDicta/feature-changelog.md`
- Website changelog: `https://vivadicta.com/ios/changelog`
- Git log since last release tag

### Step 6 — App Store description

Check if the current App Store description needs updating for new features.

Previous descriptions are stored at: `Projects/VivaDicta/description/`

**Format**: No frontmatter, no markdown header — plain text only, ready to copy-paste into App Store Connect.

**IMPORTANT**: App Store description limit is **4,000 characters**. Always verify the character count before finalizing.

If updating, save the new version as `description-X.Y.Z.md` in the same directory.

### Step 7 — Update feature changelog

Move shipped features from "Unreleased" to "Released" section in:
`Projects/VivaDicta/feature-changelog.md` (Obsidian vault)

### Step 8 — CloudKit schema deployment

If this release added or modified any SwiftData `@Model` classes that sync via CloudKit (new models, new fields, new relationships), deploy the schema to Production **before** submitting the build:

1. Run the app from Xcode to auto-create the schema in Development
2. Go to https://icloud.developer.apple.com → container `iCloud.com.antonnovoselov.VivaDicta`
3. Stay in the **Development** environment
4. Check if Indexes/Record Types/Security Roles show "Modified"
5. If yes → click **Deploy Schema Changes...** at the bottom of the sidebar → confirm → Deploy

If no SwiftData models changed, skip this step.

See `Projects/VivaDicta/CloudKit Schema Deployment.md` in the Obsidian vault for full details.

### Step 9 — Final checklist

Before handing off to `asc-release-flow`:
- [ ] Version and build number bumped across all targets
- [ ] What's New in-app screen content added
- [ ] No debug triggers left in code (forced What's New, test flags, etc.)
- [ ] Project builds with no errors
- [ ] App Store release notes prepared
- [ ] App Store description updated if needed (under 4,000 chars)
- [ ] Feature changelog updated
- [ ] CloudKit schema deployed if SwiftData models changed
- [ ] Changes committed and pushed on release branch
