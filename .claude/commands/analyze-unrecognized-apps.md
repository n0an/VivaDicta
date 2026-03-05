# Analyze Unrecognized Host Apps

**Last run:** 2026-02-28 (commit cc118f12 — added new host app mappings from analytics data)

You are given the following context:
$ARGUMENTS

## Task

Analyze unrecognized host app bundle IDs from Firebase/Google Analytics and determine which ones need URL scheme mappings added to the app.

## Instructions

1. **Read the current mappings** from `VivaDicta/VivaDictaApp.swift` — find the `knownSchemes` dictionary inside `getURLSchemeForBundleId()`

2. **Get the analytics data** — the user will provide a screenshot or list of bundle IDs from the Google Analytics "Unrecognized Host Apps" exploration (see `docs/firebase-analytics-events.md` for how to access it)

3. **Cross-reference** each bundle ID against the existing `knownSchemes` dictionary and categorize into:

   **Already mapped** — bundle ID exists in `knownSchemes` (these show up in analytics from before the mapping was added)

   **Not actionable** — system services that can't be returned to via URL scheme:
   - `(not set)` — pre-custom-dimension-registration data
   - `com.apple.SafariViewService` — SFSafariViewController embedded in other apps
   - `com.apple.springboard` — iOS home screen
   - Other Apple system services

   **Need to add** — real third-party apps not yet in `knownSchemes`

4. **Research URL schemes** for the "need to add" apps — use the web-researcher agent to search for:
   - "[app name] iOS URL scheme"
   - "[app name] deep link"
   - "[bundle id] URL scheme"
   - Known URL scheme databases and GitHub repos

5. **Output a summary table** with:
   - Bundle ID
   - Event count
   - Category (already mapped / not actionable / need to add)
   - URL scheme (if found) and confidence level

6. **After user confirms** which schemes to add, update:
   - The `knownSchemes` dictionary in `VivaDicta/VivaDictaApp.swift`
   - The `LSApplicationQueriesSchemes` array in the app's `Info.plist` (if the scheme isn't already declared there)

<IMPORTANT>
- Do NOT add URL schemes you are not confident about without user confirmation
- Low-confidence schemes should be flagged — the most reliable verification is installing the app and checking its Info.plist for CFBundleURLSchemes
- Some bundle IDs (Apple system services, embedded browser views) are not actionable and should be called out as such
</IMPORTANT>
