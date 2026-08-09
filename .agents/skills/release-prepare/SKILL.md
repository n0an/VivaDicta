---
name: release-prepare
description: Prepare a new VivaDicta release — version bump, What's New screen, App Store metadata, code sweep, and pre-submission checklist
---

# Release Prepare

Use this skill when preparing a new VivaDicta release for App Store submission.

## Version Format Convention

Use the full `X.Y.Z` form in **every user-facing surface** — never the short `X.Y` form like "3.3":

- In-app What's New screen `headline` field (e.g. `"What's New in VivaDicta 3.3.0"`)
- App Store release notes body text (e.g. `"VivaDicta 3.3.0 adds..."`)
- App Store description if it mentions the version
- Website changelog intro paragraph (the `<h2>` already shows `3.3.0`, but the prose must too)
- LinkedIn / social post copy
- Filenames: `whats-new-X.Y.Z.md`, `description-X.Y.Z.md`, `linkedin-X.Y.Z-<slug>.md`

The **only** place short `X.Y` form survives is the internal `WhatsNewCatalog.releases` dictionary key, because the version-match logic is intentionally major.minor (so 3.3.0 / 3.3.1 / 3.3.2 all hit the same entry). That key is not user-visible.

## Related Skills

- `asc-release-flow` — drive the App Store Connect submission flow (Step 11 covers the one-command `asc publish appstore` path; reach for this skill when a submission needs unpicking)
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

Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` across ALL 9 targets × 3 configs (**Debug, QA, Release**) = 27 entries each:
- VivaDicta (main app)
- VivaDictaKeyboard
- VivaDictaWidgetExtension
- ShareExtension
- ActionExtension
- VivaDictaTests
- VivaDictaWatch Watch App
- VivaDictaWatch Watch AppTests
- VivaDictaWatchWidgetExtension

> Don't hardcode the expected count - targets come and go (a `VivaDictaWatch Watch AppUITests` target existed when this was written, which is why the doc long said 30/10). Derive it instead:
> ```bash
> grep -c "MARKETING_VERSION = " VivaDicta.xcodeproj/project.pbxproj   # current entry count
> ```
> Then confirm the same number carries the new value after the sed.

Fastest approach - global sed replace catches all 30 entries in one shot:
```bash
N=$(grep -c "MARKETING_VERSION = " VivaDicta.xcodeproj/project.pbxproj)   # baseline, currently 27
grep -cE "MARKETING_VERSION = {OLD}" VivaDicta.xcodeproj/project.pbxproj  # should equal $N
sed -i '' 's/MARKETING_VERSION = {OLD};/MARKETING_VERSION = {NEW};/g' VivaDicta.xcodeproj/project.pbxproj
sed -i '' 's/CURRENT_PROJECT_VERSION = {OLD_BUILD};/CURRENT_PROJECT_VERSION = {NEW_BUILD};/g' VivaDicta.xcodeproj/project.pbxproj
# verify
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" VivaDicta.xcodeproj/project.pbxproj | sort -u  # should show only 2 unique lines
grep -c "MARKETING_VERSION = {NEW}" VivaDicta.xcodeproj/project.pbxproj   # should equal $N
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

Two things that are easy to miss, both covered in that guide:
- Prefix the new `release_X_Y` property with an ISO date comment (`// YYYY-MM-DD`) - `WhatsNewRelease` has no date field, so this comment is the file's only record of when the entry was written. Don't backfill older entries.
- The `headline` uses the full `X.Y.Z` form; only the `releases` dictionary key is `X.Y`.

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

**Primary source - the running draft**: `Projects/VivaDicta/what's new/whats-new-running.md` is a *running* accumulator of user-facing What's New items for the **upcoming** release. Add to it as features land between releases, then use it as the main source for both the in-app What's New (Step 4) and these App Store release notes.

Source features from:
- **Running draft (primary)**: `Projects/VivaDicta/what's new/whats-new-running.md`
- Obsidian vault: `Projects/VivaDicta/feature-changelog.md`
- Website changelog: `https://vivadicta.com/ios/changelog`
- Git log since last release tag

**After the release ships, empty `whats-new-running.md`** - clear all items, leaving only the `Running What's New (next release)` header line. It tracks only the *next* upcoming release, so its items must be cleared once they have shipped in `whats-new-X.Y.Z.md`. (Also in the Step 10 checklist.)

**Framing note (Apple Foundation Model)**: when a release adds on-device / local AI, only *recommend* Apple Foundation Model on **Apple-owned surfaces** - the App Store description and these release notes - so App Review sees we are not positioning against Apple's own model. On **our own channels** (in-app What's New, website changelog, LinkedIn), present the on-device feature directly, without recommending Apple FM. The "works even on devices without Apple Intelligence, including iOS 18" value angle is fine everywhere - it is a capability statement, not a recommendation.

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
# NOTE: the subcommand is `apply`, not `push` - there is no `asc metadata push`.
asc metadata apply --app 6758147238 --version X.Y.Z --platform IOS --dir ./metadata --dry-run   # always dry-run first
asc metadata apply --app 6758147238 --version X.Y.Z --platform IOS --dir ./metadata
asc validate --app 6758147238 --version X.Y.Z --platform IOS   # expect 0 errors / 0 blocking; one info-level App Privacy advisory is normal
```

### Step 8 — Update feature changelog

Move shipped features from "Unreleased" to "Released" section in:
`Projects/VivaDicta/feature-changelog.md` (Obsidian vault)

Also add a new `### vX.Y.Z (YYYY-MM-DD)` section with feature groupings and PR numbers (see earlier entries for format).

### Step 8.5 — Update iOS website changelog

The changelog is **data-driven** - do not hand-write JSX. Add a new entry to the `releases` array in:
`/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/vivadicta_website/components/ios-changelog/releases-data.tsx`

`app/ios/changelog/page.tsx` renders the index from that array, and `app/ios/changelog/[version]/` generates one static page per entry - so a new entry automatically creates `https://vivadicta.com/ios/changelog/X.Y.Z`, which is the URL the LinkedIn post links to (Step 8.6).

Insert the new object at the **top** of the array (newest first). Required fields:

```tsx
{
  version: "X.Y.Z",              // also the URL slug
  date: "YYYY-MM-DD",            // ISO, used for sorting + sitemap lastModified
  dateLabel: "Month D, YYYY",    // shown in the UI
  summary: "...",                // lead paragraph; ReactNode, so it can carry inline <Link>s
  summaryText: "...",            // plain-text lead for <meta description> / Open Graph
  groups: [
    { heading: "Feature Group", items: ["bullet 1", "bullet 2"] },
  ],
}
```

Gotchas:
- The file is `.tsx`, **not** `.ts` - `grep`/`find` for `releases-data.ts` will miss it.
- `items` entries containing an apostrophe or quotes need the string quoting swapped (`'...'` vs `"..."`) or escaping, since they are plain JS strings.
- Verify with `npm run build` and confirm the log lists `/ios/changelog/X.Y.Z` among the generated routes.

Keep copy aligned with the in-app What's New and App Store release notes so messaging stays consistent across surfaces. Commit and push in the website repo (separate from the iOS app repo - the website repo is auto-commit, no need to ask).

### Step 8.6 — Draft LinkedIn announcement post

Prepare a launch post for the **VivaDicta company page** on LinkedIn (not Anton's personal feed - the voice is announcement-style, not first-person story).

Save **two files** to `/Users/antonnovoselov/Documents/Vault/Projects/VivaDicta/linkedin-posts/`:

- `linkedin-X.Y.Z-<slug>.md` - the working draft (all variants + posting notes below). Normal blank lines so it reads cleanly in Obsidian.
- `linkedin-X.Y.Z-<slug>-copy.md` - the paste-ready primary draft **only**, formatted for LinkedIn's composer (see "LinkedIn composer formatting" below). No headings, no frontmatter, no variants - just the exact text that goes into the composer.

The working draft (`.md`) should include:

1. **Primary draft** - ready to paste. Lead with a one-line release announcement, one paragraph framing the headline feature, then a tight bullet list (4-6 items) of other release highlights, then a link.
2. **Spartan alternate** - bullets only, no narrative paragraph. Mirrors the Summit AI Notes template (line 1 = announcement, then bullets, "and more.", link).
3. **2-3 alternate hook lines** - so the user can swap if the marquee feels wrong.
4. **Posting notes** - media suggestion, recommended post window (Tue/Wed/Thu, 9-11am), instruction to pin the App Store link as the first comment.

Style rules (also in `~/.claude/skills/linkedin-post-style/SKILL.md`):
- Company-page voice: no "I", no personal-story narrative, no "thrilled to announce" filler.
- Short paragraphs (1-2 sentences), line breaks over dense blocks.
- Normal dashes, never em-dashes.
- For unordered lists use `➡️ ` as the bullet marker (one per item, followed by a space), never `-`, `*`, or `•`. Numbered lists still use `1.`, `2.`, etc.
- The link in the body should be the **version-specific website changelog page** (`https://vivadicta.com/ios/changelog/X.Y.Z`, e.g. `https://vivadicta.com/ios/changelog/3.5.0`) - the per-release deep page, not the generic `/ios/changelog` list and not the App Store URL. Pin the App Store URL as the first comment instead - this gives commenters two routes (deep-context page in body, one-click install in comment).
- For the marquee feature, use a tagline that reads as **what the experience feels like**, not what it historically was. Avoid hyperbolic "only [elite group] had this" framing - LinkedIn's tech-literate audience will dunk on overstatement, especially for capabilities competitors have shipped (real-time translation, on-device AI, etc.).

**LinkedIn composer formatting (the `-copy.md` whitespace hack):** LinkedIn's web composer collapses true blank lines when you paste plain text, destroying the paragraph spacing. So in the paste-ready `-copy.md`, every otherwise-blank line between paragraphs must contain a single Braille pattern blank character `⠀` (U+2800), not be empty. LinkedIn treats a line containing `⠀` as having content and preserves it as visible spacing, and the character renders invisibly to readers. Apply this **only** to `-copy.md` - leave the working `.md` draft with normal blank lines so it stays readable in Obsidian. (Same convention as the user-level `linkedin-post-style` skill, which is the source of truth for Anton's LinkedIn formatting.)

Publishing happens **after** the App Store build is approved and live, so users hitting the post can install immediately. The draft is prepared during release prep so it's ready to go when approval lands.

### Step 8.7 — Refresh website llms.txt / llms-full.txt

Update the AI-discoverability files in the website repo so they track the current feature set:
- `/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/vivadicta_website/public/llms.txt` (short summary)
- `/Users/antonnovoselov/Desktop/_Projects/iOS/VivaDictaMeta/vivadicta_website/public/llms-full.txt` (full doc)

These are easy to forget - nothing auto-generates them, and the major chatbots do **not** auto-fetch `/llms.txt` (it's a voluntary convention; mainly agents/dev tools that deliberately fetch it benefit). Still, on each release re-sync them against this release's changes so anything that does read them sees current data:

- **Transcription providers** - the cloud list + default models (source of truth: iOS `AIProvider.swift` `defaultModel` / `availableModels` and `TranscriptionKit`).
- **AI enhancement providers** - the `## AI Enhancement Providers` table, the provider count ("N+ AI providers"), and the one-line provider list in `llms.txt` (source: `AIProvider.generalProviders`). Add any provider shipped this release.
- **Preset count / categories**, **translation languages**, **supported file formats**, **pricing**, **system requirements** - update only if they changed this release.
- Keep wording aligned with the in-app What's New, App Store notes, and website changelog (Steps 4, 5, 8.5).

Commit and push in the website repo (can be folded into the same commit as Step 8.5, since both touch that repo).

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
- **Export compliance / encryption**: always "No - app does not use non-exempt encryption". The app doesn't ship its own encryption; any HTTPS usage is covered by the standard exemption. **This is now declared permanently** by `ITSAppUsesNonExemptEncryption = false` in `VivaDicta/Info.plist`, so uploaded builds arrive already `exempt` and nobody should be asked. If a build ever shows `n/a` in `asc builds list`, that key went missing - fix the plist rather than patching the build.

Before shipping (Step 11):
- [ ] Version and build number bumped across all 9 targets (27 pbxproj entries - verify with `grep -c`)
- [ ] What's New in-app screen content added, with the `// YYYY-MM-DD` comment above the new `release_X_Y` property
- [ ] No debug triggers left in code (forced What's New, test flags, etc.)
- [ ] Project builds with no errors
- [ ] App Store release notes prepared (vault + `whats-new-X.Y.Z.md`)
- [ ] App Store description updated if needed (under 4,000 chars)
- [ ] `metadata/version/X.Y.Z/*.json` generated for all 10 locales
- [ ] Feature changelog updated (Obsidian vault)
- [ ] iOS website changelog updated (`vivadicta_website/components/ios-changelog/releases-data.tsx` + `npm run build` + push)
- [ ] Website `llms.txt` + `llms-full.txt` refreshed if providers/presets/pricing changed (`vivadicta_website/public/` + push)
- [ ] LinkedIn announcement drafted - working `.md` + paste-ready `-copy.md` (with `⠀` U+2800 blank lines and `➡️` bullets) in `Projects/VivaDicta/linkedin-posts/` - publish after App Store approval lands
- [ ] CloudKit schema deployed if SwiftData models changed
- [ ] Review Notes: testing instructions only (remove any rejection-specific notes from previous submissions)
- [ ] Changes committed and pushed on release branch
- [ ] After build upload: `asc metadata apply` + `asc validate` returns 0 errors / 0 blocking (one info-level App Privacy advisory is expected)
- [ ] App Privacy confirmed published - `asc validate` **cannot** verify this via the public API, so it must be eyeballed: https://appstoreconnect.apple.com/apps/6758147238/appPrivacy
- [ ] After the release ships: empty `whats-new-running.md` (clear items, keep the `Running What's New (next release)` header) so it only tracks the next upcoming release

### Step 11 — Ship it (archive → upload → attach → submit)

All five formerly-manual App Store Connect steps are automatable. `asc publish appstore` is the canonical high-level command and does the whole chain:

1. Archive + export locally (drives `xcodebuild` itself in local-build mode)
2. Upload the IPA, wait for processing
3. Find or create the App Store version
4. Apply version localization metadata from `--metadata-dir`
5. Attach the build
6. Submit for review (`--submit --confirm`)

Export compliance is **not** a step here - it is declared once in `VivaDicta/Info.plist` (see Step 10).

#### Always dry-run first

```bash
asc publish appstore --app 6758147238 --version X.Y.Z \
  --workspace ./VivaDicta.xcodeproj/project.xcworkspace --scheme VivaDicta \
  --metadata-dir ./metadata --dry-run
```

#### The real run

```bash
# Stage everything but stop before review (safe default - prefer this)
asc publish appstore --app 6758147238 --version X.Y.Z \
  --workspace ./VivaDicta.xcodeproj/project.xcworkspace --scheme VivaDicta \
  --export-options ./ExportOptions.plist \
  --metadata-dir ./metadata --wait

asc validate --app 6758147238 --version X.Y.Z --platform IOS   # expect 0 errors / 0 blocking

# Then, and only with explicit sign-off, submit:
asc publish appstore --app 6758147238 --version X.Y.Z --submit --confirm
```

**Archiving is slow** (18 SPM modules, 9 targets). Run it backgrounded and poll rather than blocking the session.

#### Prerequisites

- **`ExportOptions.plist`** at the repo root - required by local-build mode. `method` = `app-store-connect`, plus the team ID.
- **Non-interactive code signing.** If the login keychain prompts for the Distribution private key the archive dies mid-run. `security unlock-keychain` once per session fixes it.
- **`asc auth`** configured (`asc doctor` diagnoses).

#### Never automate without explicit sign-off

`--submit --confirm` puts the app in front of App Review. Treat it like a deploy: always ask, every single time, even though the rest of the chain is automatic. Everything up to and including `attach build` is reversible; submission is not (only cancellable).

#### Alternative: stage without submitting

```bash
asc release stage --app 6758147238 --version X.Y.Z --build BUILD_ID --metadata-dir ./metadata --confirm
```

Same pipeline, hard-stops before creating a review submission.

#### Readiness checks

```bash
asc review doctor --app 6758147238    # "nextAction" tells you exactly what is blocking
asc review status --app 6758147238
```

#### Gotchas found in practice

- `asc versions view` shows **empty Build ID / Build Version columns even when a build is correctly attached** - ASC omits relationship linkage unless `?include=` is passed, and the command does not. Do **not** read that as a missing build. `asc validate` is authoritative: its `build.required.missing` error clears the moment the build is attached.
- `asc builds update --uses-non-exempt-encryption=false` is only a per-build patch for builds uploaded before the Info.plist key existed. The plist key is the real fix.
- `asc metadata apply` reports `add` for `whatsNew` on a fresh version (the field does not exist yet) and `update` for `description`. Seeing zero `keywords` rows is the signal the per-locale ASO keyword sets were preserved - if keywords ever appear in the plan, stop and investigate.
- Run `asc metadata apply` **without** `--allow-deletes`. With it, any locale missing locally is planned as a delete.
