---
name: analyze-unrecognized-apps
description: Analyze unrecognized host app bundle IDs from Firebase/Google Analytics and add URL scheme mappings
disable-model-invocation: true
---

# Analyze Unrecognized Host Apps

**Last run:** 2026-08-29 - added 15 return-URL mappings (Swiftgram, Open Minis, WeChat, Spotify team-ID variant, Reminders, Letterboxd, Eudic, Notion, Meituan, nPlayer, plus 5 universal-link fallbacks) and 5 knownNoSchemeHosts entries. Also removed the `canOpenURL` gate and the dead `LSApplicationQueriesSchemes` array, which had exceeded Apple's 50-entry cap and was silently killing the most recent mappings. Note: this sample predates the iOS 26.4 host-resolution fix, so it under-reports - re-run once 3.9.0 has been out a few weeks.

You are given the following context:
$ARGUMENTS

## Task

Analyze unrecognized host app bundle IDs from Firebase/Google Analytics and determine which ones need URL scheme mappings added to the app.

## Instructions

1. **Read the current mappings** from `VivaDicta/VivaDictaApp.swift` — find the `knownURLs` dictionary inside `returnURL(forHostId:)`. The `knownNoSchemeHosts` set lives just above it, in `attemptReturnToHost(hostId:)`.

2. **Get the analytics data** — the user will provide a screenshot or list of bundle IDs from the Google Analytics "Unrecognized Host Apps" exploration (see `internal/firebase-analytics-events.md` for how to access it)

3. **Cross-reference** each bundle ID against `knownURLs` and `knownNoSchemeHosts`, and categorize into:

   **Already mapped** — bundle ID exists in `knownURLs` (these show up in analytics from before the mapping was added)

   **Variant of a mapped app** — same app under a different bundle ID: a team-ID suffix (`com.spotify.client.L32G8C83V9`), a regional build (`com.amazon.AmazonDE`), or an app extension (`net.whatsapp.WhatsApp.ShareExtension`). Aliasing a suffixed build to the same URL is safe. An *extension* is a judgement call — returning to the parent app is not the surface the user was in.

   **Not actionable** — system services that can't be returned to:
   - `(not set)` — pre-custom-dimension-registration data
   - `com.apple.SafariViewService` — SFSafariViewController embedded in other apps
   - `com.apple.springboard` — iOS home screen
   - Other Apple system services

   **Need to add** — real third-party apps not yet in `knownURLs`

4. **Research a way back** for the "need to add" apps. Search for:
   - "[app name] iOS URL scheme"
   - "[app name] deep link"
   - "[bundle id] URL scheme"
   - Known URL scheme databases and GitHub repos

   Two sources beat any blog list, and are worth the extra step for high-volume apps:
   - **The app's own registration** — its open-source `Info.plist` or build file (`CFBundleURLSchemes`), or, for Apple apps, the binary in a simulator runtime under `/Library/Developer/CoreSimulator/.../RuntimeRoot/Applications/`.
   - **The app's AASA file** — `https://<domain>/.well-known/apple-app-site-association`. If it lists the bundle ID, the matching `https://` URL is a valid fallback for an app that registers no custom scheme. This works *only* on this code path, because the lookup runs solely for the app the keyboard was just typing into, so it is installed by definition.

   Watch for schemes shared between apps. Swiftgram registers `tg://` *and* `telegram://` alongside official Telegram; iOS picks between claimants unpredictably, so map only a scheme the app owns outright (`sg://`).

5. **Output a summary table** with:
   - Bundle ID
   - Event count
   - Category (already mapped / variant / not actionable / need to add)
   - Return URL (if found) and confidence level

6. **After user confirms** which entries to add, update `VivaDicta/VivaDictaApp.swift`:
   - Apps with a way back → the `knownURLs` dictionary in `returnURL(forHostId:)`
   - Apps with none → the `knownNoSchemeHosts` set, so they stop being reported as unrecognized

   **There is no plist step, and adding one is a regression.** `LSApplicationQueriesSchemes` was deleted on 2026-08-29 along with the `canOpenURL` gate it existed to permit. Apple caps that array at 50 entries, and past the cap `canOpenURL` returns false whether or not the app is installed — which silently killed the newest mappings. `UIApplication.open` needs no declaration and reports failure through its own result, so the table can now grow without limit. Do not reintroduce either.

7. **Update the "Last run" line** at the top of this file with the date and what changed.

<IMPORTANT>
- Do NOT add URL schemes you are not confident about without user confirmation
- Low-confidence schemes should be flagged — the most reliable verification is the app's own `CFBundleURLSchemes`, from its source, its shipped binary, or an installed copy
- Some bundle IDs (Apple system services, embedded browser views) are not actionable and should be called out as such
- Treat the event counts as a floor, not a census. `.unrecognizedHostApp` only fires when the keyboard resolves a host bundle ID, so any period where resolution was broken under-reports every app at once
</IMPORTANT>
