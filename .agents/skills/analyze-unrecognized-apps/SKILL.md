---
name: analyze-unrecognized-apps
description: Analyze unrecognized host app bundle IDs from Firebase/Google Analytics and add URL scheme mappings
disable-model-invocation: true
---

# Analyze Unrecognized Host Apps

**Last run:** 2026-09-05 - added 29 return-URL mappings (Happy Coder, Kelivo, Simplenote, Drafts, Uber, Slack, Evernote, LINE, YouTube, eBay, Google Docs, Taobao, Arc Search, plus 5 AASA universal-link fallbacks for Amazon US/UK, ClassDojo, Mercari and Uber Eats) and 11 knownNoSchemeHosts entries. Three mappings (Alibaba `enalibaba://`, Beeper `beeper://`, DiDi `diditaxi://`) went in at explicitly lower confidence and sit under their own comment block. Two lookup techniques worth reusing: the iTunes lookup API (`https://itunes.apple.com/lookup?bundleId=...`) resolves a bundle ID to an app name and seller URL in one call, and it caught a misidentification - `com.codality.NotationalFlow` is Simplenote, not the note app the name suggests; and an AASA is not always at `/.well-known/` (Hevy serves its own at `https://hevy.com/apple-app-site-association`). Also note an AASA entry with an empty `paths` array (DeepSeek) matches nothing and is not a usable fallback. This sample still predates the iOS 26.4 host-resolution fix, so it under-reports.

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
