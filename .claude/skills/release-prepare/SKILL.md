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

Use the same English text for all localizations (for ASO reasons).

Source features from:
- Obsidian vault: `Projects/VivaDicta/feature-changelog.md`
- Website changelog: `https://vivadicta.com/ios/changelog`
- Git log since last release tag

### Step 6 — App Store description

Check if the current App Store description needs updating for new features.

Previous descriptions are stored at: `Projects/VivaDicta/description/`

**IMPORTANT**: App Store description limit is **4,000 characters**. Always verify the character count before finalizing. Count only the description text, excluding frontmatter.

If updating, save the new version as `description-X.Y.Z.md` in the same directory.

### Step 7 — Update feature changelog

Move shipped features from "Unreleased" to "Released" section in:
`Projects/VivaDicta/feature-changelog.md` (Obsidian vault)

### Step 8 — Final checklist

Before handing off to `asc-release-flow`:
- [ ] Version and build number bumped across all targets
- [ ] What's New in-app screen content added
- [ ] No debug triggers left in code (forced What's New, test flags, etc.)
- [ ] Project builds with no errors
- [ ] App Store release notes prepared
- [ ] App Store description updated if needed (under 4,000 chars)
- [ ] Feature changelog updated
- [ ] Changes committed and pushed on release branch
