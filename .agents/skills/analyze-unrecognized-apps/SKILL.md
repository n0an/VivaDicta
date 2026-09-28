---
name: analyze-unrecognized-apps
description: Pull unrecognized host app bundle IDs from Google Analytics via gog, diff them against the mapping tables and add URL scheme mappings
disable-model-invocation: true
---

# Analyze Unrecognized Host Apps

**Last run:** 2026-09-28 (weekly GA batch, automated) - one new bundle ID in the 28-day window (`com.omachala.happy`, 2 events): a personal fork of Happy whose `app.config.js` registers the same `happy://` scheme as the already-mapped `com.ex3ndr.happy`, so it went into `knownNoSchemeHosts` (shared scheme, never map). No return-URL mappings added. The script reports "nothing new" at the default settings.

Previous run 2026-09-27 (second pass) - cleared the 35 single-event bundle IDs left over from the first pass, plus Bear, which arrived since. Added 24 return-URL mappings (9 schemes read from the app's own source or the simulator runtime, 5 AASA-confirmed universal links, 10 under the weaker block) and 12 `knownNoSchemeHosts` entries. The script now reports "nothing new" at the default settings. Also rewrote the Prerequisites: the documented `gog auth add --services analytics` command both narrows the token and is refused by Google because of stale YouTube grants on gog's OAuth client, so the remote flow with `include_granted_scopes` stripped is the working recipe. Findings worth keeping: `ru.yandex.mobile.search` is Yandex **Browser**, not the Yandex app (`ru.yandex.mobile`); X Chat and QuickPaste have no way back at all; Brave and Firefox also claim `http`/`https`, so map only `brave://` / `firefox://`; Apple's Translate and Image Playground are only localization stubs in the iOS 27 simulator runtime, so their schemes cannot be read there.

Previous run 2026-09-27 (first pass) - first run on the gog pipeline (`scripts/unrecognized_host_apps.py`, 28-day window, 132 bundle IDs / 528 events, 29 rows with two or more events). Added 17 return-URL mappings and 12 `knownNoSchemeHosts` entries; after the edit the script reports "nothing new" at `--min-events 2`. Twelve mappings are AASA-confirmed at the root or a catch-all path, five went in under a weaker block (AASA matches only a specific page, or the scheme comes from vendor docs). Identity checks via `itunes.apple.com/lookup?bundleId=` paid off: `co.anysphere.sand` is Grok Bot by X, not Cursor (its x.ai AASA matches only concrete share ids, so noScheme); `com.jiangjia.gif` is Kuaishou; `com.supersethealth.superset` is now Bevel; `ru.yandex.uber` now belongs to Fasten. VK's main client went in as `https://vk.com/feed`, not `vk://`, because several VK apps share the team. `com.apple.Preferences` went to noScheme: its only route is the private `App-prefs://`. The 34 single-event bundle IDs were left for a later batch. Previous run 2026-09-12 (19 mappings, 16 noScheme) established: the AASA is often the fastest primary source even for apps that do have a scheme; an app's build manifest beats its Info.plist when the scheme is a build variable; Telegram forks must never be mapped to `tg://`; share extensions go to noScheme, editor extensions whose content lives in the parent app are aliased to it.

You are given the following context:
$ARGUMENTS

## Task

Pull the `unrecognized_host_app` bundle IDs from Google Analytics, work out which ones need a return URL, and add the mappings to the app.

## Prerequisites (one-time)

The data comes from the GA4 Analytics Data API through the `gog` CLI (`brew install gog` if missing). The stored gog token for `anton.novoselov@gmail.com` must carry the `analytics.readonly` scope; the default services do not include it. Check with `gog auth list -p`: the services column must include `analytics`. The Mac token has had it since 2026-09-27, so this is only needed after a token reset.

**Do not run a bare `gog auth add ... --services analytics --force-consent`.** It fails in two ways:
- `--services` *replaces* the token's service set, so passing only `analytics` would leave a token with nothing else. Always pass the full current list from `gog auth list -p`, plus `analytics`.
- gog's OAuth client once received YouTube grants, and gog adds `include_granted_scopes=true` to every consent URL. Google merges those old grants into the request and refuses it: "Access blocked: Authorization Error ... scopes that cannot be requested together (youtube.force-ssl, drive.file, youtube, ...)", Error 400 `invalid_request`.

What works is the remote flow, with that flag stripped from the URL:

```bash
SERVICES=appscript,calendar,chat,classroom,contacts,docs,drive,forms,gmail,people,sheets,slides,tasks,analytics   # current list + analytics
# 1. print the consent URL, drop the scope-merge flag, open it
gog auth add anton.novoselov@gmail.com --services $SERVICES --force-consent --remote --step 1 \
  | awk -F'\t' '/^auth_url/{print $2}' | sed 's/&include_granted_scopes=true//' | xargs open
# 2. approve; the browser lands on an unreachable http://127.0.0.1:<port>/oauth2/callback?... page. That is expected.
#    Copy that full URL, then exchange it (within ~5 minutes of step 1):
gog auth add anton.novoselov@gmail.com --services $SERVICES --force-consent --remote --step 2 --auth-url '<callback URL>'
```

An agent can run both steps itself: step 1, hand the user the link, then run step 2 with the callback URL they paste back.

Verify:

```bash
gog ga report "$(cat internal/ga_property_id)" --dimensions eventName --metrics eventCount --from 7daysAgo --max 2 -p
```

A 403 `insufficientPermissions` means the scope is still missing; the script points back to this section. The GA4 property ID (the property behind the Firebase project `vivadicta`) is private: it lives in the gitignored `internal/ga_property_id`, which the script reads (`$GA_PROPERTY_ID` overrides it). The account ID, the Explore report URL and the OAuth client details are in `internal/firebase-analytics-events.md`. On a fresh clone, create `internal/ga_property_id` first. The event is `unrecognized_host_app`, the bundle ID lives in the custom event dimension `bundle_id` (registered 2026-02-24; older hits show as `(not set)`).

## Instructions

1. **Read the current mappings** from `VivaDicta/VivaDictaApp.swift` — find the `knownURLs` dictionary inside `returnURL(forHostId:)`. The `knownNoSchemeHosts` set lives just above it, in `attemptReturnToHost(hostId:)`.

2. **Pull and diff the analytics data** with the repo script, which runs `gog ga report`, filters the event client-side (the CLI has no filter flag) and compares every bundle ID against both tables in the local Swift file:

   ```bash
   scripts/unrecognized_host_apps.py                  # last 28 days, actionable rows only
   scripts/unrecognized_host_apps.py --days 90 --all  # longer window, include mapped/noScheme rows
   scripts/unrecognized_host_apps.py --json /tmp/unrecognized.json   # machine-readable copy
   ```

   The default window is 28 days, which is what the weekly run wants: old app versions keep reporting apps that are already mapped, and the script hides those. Exit code 3 means nothing actionable - stop and say so. Use `--min-events 2` to skip singletons when the list is long; singletons still deserve a look when they are obviously popular apps.

   **Fallback only if the API is unavailable:** the user can paste a screenshot or list from the GA Explore exploration "Unrecognized Host Apps" (URL in `internal/firebase-analytics-events.md`; also reachable from Firebase Console → Analytics → "View more in Google Analytics"). Then do the cross-reference from step 3 by hand.

3. **Review the script's categories** — it prints one of these per bundle ID; check the automatic verdicts rather than re-deriving them:

   **`mapped`** — already in `knownURLs` (hidden unless `--all`; it shows up from app versions that predate the mapping)

   **`noscheme`** — already in `knownNoSchemeHosts` (hidden unless `--all`)

   **`variant:<id>`** — same app as a mapped `<id>` under a different bundle ID: a team-ID prefix (`4GU63N96WE.com.p5sys.jumpdesktop`), a regional build (`com.amazon.AmazonDE`), or an app extension (`net.whatsapp.WhatsApp.ShareExtension`). Aliasing a prefixed or regional build to the same URL is safe. An *extension* is a judgement call — returning to the parent app is not the surface the user was in. The script only detects prefix/suffix variants; spot regional builds (`AmazonUK` vs `Amazon`) yourself.

   **`apple-new`** — `com.apple.*` not in either table. Usually a system service that cannot be returned to (`com.apple.SafariViewService`, `com.apple.springboard`, `com.apple.siri`) and belongs in `knownNoSchemeHosts`; some Apple apps do have schemes (`shortcuts://`, `mobilenotes://`, `maps://`), check the simulator runtime binary before deciding.

   **`new`** — real third-party app not yet in either table. These are the research queue.

   **`not-actionable`** — `(not set)`, pre-custom-dimension data. Ignore.

4. **Research a way back** for each `new` app. Search for:
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
   - Category (mapped / variant / apple-new / new / not actionable)
   - Return URL (if found), confidence level and the source it came from

6. **After user confirms** which entries to add, update `VivaDicta/VivaDictaApp.swift`:
   - Apps with a way back → the `knownURLs` dictionary in `returnURL(forHostId:)`
   - Apps with none → the `knownNoSchemeHosts` set, so they stop being reported as unrecognized

   Re-run `scripts/unrecognized_host_apps.py` afterwards: every row you handled must now come back as `mapped` or `noscheme` (visible with `--all`), which also proves the Swift edit parses.

   **There is no plist step, and adding one is a regression.** `LSApplicationQueriesSchemes` was deleted on 2026-08-29 along with the `canOpenURL` gate it existed to permit. Apple caps that array at 50 entries, and past the cap `canOpenURL` returns false whether or not the app is installed — which silently killed the newest mappings. `UIApplication.open` needs no declaration and reports failure through its own result, so the table can now grow without limit. Do not reintroduce either.

7. **Update the "Last run" line** at the top of this file with the date and what changed.

<IMPORTANT>
- Do NOT add URL schemes you are not confident about without user confirmation
- Low-confidence schemes should be flagged — the most reliable verification is the app's own `CFBundleURLSchemes`, from its source, its shipped binary, or an installed copy
- Some bundle IDs (Apple system services, embedded browser views) are not actionable and should be called out as such
- Treat the event counts as a floor, not a census. `.unrecognizedHostApp` only fires when the keyboard resolves a host bundle ID, so any period where resolution was broken under-reports every app at once
- The script reads the tables from the working tree, so run it on the branch you are about to edit; a parse failure ("could not parse knownURLs / knownNoSchemeHosts") means the Swift declarations moved or were renamed - fix the regexes in `scripts/unrecognized_host_apps.py`, do not fall back to screenshots
</IMPORTANT>
