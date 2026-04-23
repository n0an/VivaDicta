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

Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` across ALL 10 targets × 3 configs (**Debug, QA, Release**) = 30 entries each:
- VivaDicta (main app)
- VivaDictaKeyboard
- VivaDictaWidget
- ShareExtension
- ActionExtension
- VivaDictaTests
- VivaDictaWatch Watch App
- VivaDictaWatch Watch AppTests
- VivaDictaWatch Watch AppUITests
- VivaDictaWatchWidgetExtension

Fastest approach - global sed replace catches all 30 entries in one shot:
```bash
grep -cE "MARKETING_VERSION = {OLD}" VivaDicta.xcodeproj/project.pbxproj  # should print 30
sed -i '' 's/MARKETING_VERSION = {OLD};/MARKETING_VERSION = {NEW};/g' VivaDicta.xcodeproj/project.pbxproj
sed -i '' 's/CURRENT_PROJECT_VERSION = {OLD_BUILD};/CURRENT_PROJECT_VERSION = {NEW_BUILD};/g' VivaDicta.xcodeproj/project.pbxproj
# verify
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" VivaDicta.xcodeproj/project.pbxproj | sort -u  # should show only 2 unique lines
```

Convention: `CURRENT_PROJECT_VERSION` is a **monotonic counter**, independent of `MARKETING_VERSION`. Bump it by `+1` for every new build uploaded to TestFlight/App Store Connect, regardless of whether the marketing version changed. Apple only requires the build number to be strictly greater than any previously uploaded build for the same marketing version, so a plain incrementing integer is the simplest correct approach.

Before editing, check the current value:
```
grep -E "CURRENT_PROJECT_VERSION" VivaDicta.xcodeproj/project.pbxproj | head -1
```
Then use `current + 1` as the new value across all targets.

> **Legacy note**: earlier releases up through `3.0.0` used a packed `XYZN` scheme (e.g. `1.1.0 → 1101`, `3.0.0 → 3001`), which is why the counter currently sits at a value like `3001`-ish. That scheme is abandoned because it caps each segment at 9. Going forward, just `+1` from the last build number - do NOT try to re-pack based on the marketing version.

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

**Read the guide first**: `Projects/VivaDicta/description/description-guide.md` - covers structure, writing rules, and common pitfalls for both What's New and description text.

**Format**: No frontmatter, no markdown header — plain text only, ready to copy-paste into App Store Connect.

**IMPORTANT**: App Store What's New (release notes) limit is **4,000 characters**. Always verify the character count.

**ASO strategy** (important, easy to misread):
- `description` + `whatsNew` → **identical English text in all 10 locales** (no translation)
- `keywords` → **unique per locale** (this is the ASO hack - different keyword sets target different search markets)
- `marketingUrl` + `supportUrl` → same across locales

Source features from:
- Obsidian vault: `Projects/VivaDicta/feature-changelog.md`
- Website changelog: `https://vivadicta.com/ios/changelog`
- Git log since last release tag

### Step 6 — App Store description

Check if the current App Store description needs updating for new features.

**Read the guide first**: `Projects/VivaDicta/description/description-guide.md` - covers section ordering, core identity rules, jargon avoidance, and Apple Foundation Model placement.

Previous descriptions are stored at: `Projects/VivaDicta/description/`

**Format**: No frontmatter, no markdown header — plain text only, ready to copy-paste into App Store Connect.

**IMPORTANT**: App Store description limit is **4,000 characters**. Always verify the character count before finalizing.

If updating, save the new version as `description-X.Y.Z.md` in the same directory.

### Step 7 — Generate ASC metadata directory for the new version

Create `metadata/version/X.Y.Z/*.json` for all 10 locales, ready to push to App Store Connect via `asc`. The directory is gitignored - ASC is source of truth, this is just the staging payload.

Seed from the previous version, overwrite `description` and `whatsNew` with the new English text, keep per-locale `keywords`/`marketingUrl`/`supportUrl` untouched:

```bash
mkdir -p metadata/version/{NEW}
python3 << 'PYEOF'
import json
locales = ['ar-SA','en-US','es-MX','fr-FR','ko','pt-BR','ru','vi','zh-Hans','zh-Hant']
with open("/Users/antonnovoselov/Documents/Vault/Projects/VivaDicta/description/description-{NEW}.md") as f:
    new_desc = f.read().rstrip('\n') + '\n'
with open("/Users/antonnovoselov/Documents/Vault/Projects/VivaDicta/what's new/whats-new-{NEW}.md") as f:
    new_wn = f.read().rstrip('\n') + '\n'
for loc in locales:
    with open(f'metadata/version/{PREV}/{loc}.json') as f:
        d = json.load(f)
    d['description'] = new_desc
    d['whatsNew'] = new_wn
    with open(f'metadata/version/{NEW}/{loc}.json', 'w') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
PYEOF
```

Push happens during submission (see Step 10):
```bash
asc metadata push --app 6758147238 --version X.Y.Z --platform IOS --dir ./metadata
asc submit preflight --app 6758147238 --version X.Y.Z --platform IOS   # expect 9/9 pass
```

### Step 8 — Update feature changelog

Move shipped features from "Unreleased" to "Released" section in:
`Projects/VivaDicta/feature-changelog.md` (Obsidian vault)

### Step 9 — CloudKit schema deployment

First, detect whether any SwiftData `@Model` classes changed since the last release tag:

```bash
git diff v{PREV}..HEAD -- 'VivaDicta/Models/*.swift' | grep -E "^\+.*(@Model|^\+\s+(var|let) )" | head -20
```

If new fields / relationships / models appear, deploy the CloudKit schema to Production **before** submitting the build:

1. Run the app from Xcode to auto-create the schema in Development
2. Go to https://icloud.developer.apple.com → container `iCloud.com.antonnovoselov.VivaDicta`
3. Stay in the **Development** environment
4. Check if Indexes/Record Types/Security Roles show "Modified"
5. If yes → click **Deploy Schema Changes...** at the bottom of the sidebar → confirm → Deploy

If no SwiftData models changed, skip this step.

See `Projects/VivaDicta/CloudKit Schema Deployment.md` in the Obsidian vault for full details.

### Step 10 — Final checklist

Known-answer ASC questions (don't re-ask these):
- **Export compliance / encryption**: always "No - app does not use non-exempt encryption". The app doesn't ship its own encryption; any HTTPS usage is covered by the standard exemption.

Before handing off to `asc-release-flow`:
- [ ] Version and build number bumped across all 10 targets (30 pbxproj entries)
- [ ] What's New in-app screen content added
- [ ] No debug triggers left in code (forced What's New, test flags, etc.)
- [ ] Project builds with no errors
- [ ] App Store release notes prepared (vault + `whats-new-X.Y.Z.md`)
- [ ] App Store description updated if needed (under 4,000 chars)
- [ ] `metadata/version/X.Y.Z/*.json` generated for all 10 locales
- [ ] Feature changelog updated
- [ ] CloudKit schema deployed if SwiftData models changed
- [ ] Review Notes: testing instructions only (remove any rejection-specific notes from previous submissions)
- [ ] Changes committed and pushed on release branch
- [ ] After build upload: `asc metadata push` + `asc submit preflight` passes 9/9 (App Privacy advisory is expected)
