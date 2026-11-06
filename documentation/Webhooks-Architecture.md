# Webhooks Architecture

## Overview

After a recording is transcribed and AI-processed, VivaDicta can POST the result as JSON to a user-configured webhook. Each mode picks one webhook or none. Typical receivers are n8n, Zapier, Make, or the user's own server.

Delivery goes through a persistent outbox and an in-process `URLSession` that refuses redirects. Sends and retries run while the app runs, and the app holds background time while an upload is in flight. A failing webhook never blocks or delays transcription, the Obsidian hand-off or folder export.

## Components

| Type | File | Role |
|------|------|------|
| `WebhookDefinition` | `Services/Webhooks/WebhookDefinition.swift` | Name, https URL, enabled flag, `hasBearerToken`, `textContent` (`WebhookTextContent`). Also `WebhookURLValidator` and `WebhookDeliveryStatus` |
| `WebhookStore` | `Services/Webhooks/WebhookStore.swift` | Definitions and last status per webhook (app-private UserDefaults). Bearer tokens in the Keychain as `AfterFirstUnlockThisDeviceOnly` items, so a send that runs while the phone is locked (for example a watch recording processed in the background) can read them |
| `WebhookPayloadBuilder` | `Services/Webhooks/WebhookPayload.swift` | Pure payload composition and the request headers (`WebhookRequestBuilder`) |
| `WebhookRetryPolicy` | `Services/Webhooks/WebhookRetryPolicy.swift` | Pure retry and stop rules, backoff, `Retry-After`, max age |
| `WebhookOutboxStorage` | `Services/Webhooks/WebhookOutbox.swift` | `Application Support/Webhooks/outbox.json` plus one body file per item |
| `URLSessionWebhookTransport` | `Services/Webhooks/WebhookTransport.swift` | File-backed upload tasks in an ephemeral, in-process session that refuses redirects |
| `WebhookRedirects` | `Services/Webhooks/WebhookRedirects.swift` | Redirect rules: the Send Test session, `WebhookRedirectRefuser`, and the check that a response came from the requested URL |
| `WebhookDeliveryService` | `Services/Webhooks/WebhookDeliveryService.swift` | Orchestrates enqueue, delivery, retries, reconciliation and manual sends |
| `ImportedAudioRecordingDate` | `Modules/AppGroup/Sources/AppGroup/ImportedAudioRecordingDate.swift` | Reads and vets the recording date of an imported file (see Recording time) |
| `RecordingTime` | `Models/RecordingTime.swift` | Carries what is known about the recording time from where audio enters to `Transcription.recordedAt` |

`VivaMode.webhookID` holds the per-mode choice. It is decoded with `decodeIfPresent`, so modes saved by older versions still load. Deleting a webhook clears it from every mode (`AIService.clearWebhookReferences(to:)`) and drops its pending items.

Modes and webhook definitions are device-local (App Group / app-private UserDefaults). The recording time is stored on the note as `Transcription.recordedAt`, an optional SwiftData field that syncs through CloudKit (see Recording time).

## Where sends start

`WebhookDeliveryService.enqueueIfEnabled(transcription:mode:languageOverride:)` runs next to `FolderExportService.saveIfEnabled`:

- `RecordViewModel.transcribeSpeechTask`: in-app recording, keyboard recordings, share / action extension audio, file import, App Intents (they drive the in-app recorder)
- `RecordViewModel.cancelProcessing`: the transcript saved when AI processing is cancelled
- `WatchAudioProcessor.processAudioFile`: Apple Watch recordings, using the mode the watch recording was made with

Live Translation sessions save their own transcriptions and are not sent.

Manual send: the share menu on the transcription detail screen lists enabled webhooks ("Send to <name>", or a submenu when several exist).

## Delivery

1. The payload is encoded and written to a body file; the outbox index is saved. A newer send of the same note to the same webhook supersedes a pending one.
2. `pump()` starts an upload task for each due item. The request (URL, token) is built per attempt from the current definition. If the webhook has a token but the Keychain is unavailable (device locked), the item waits rather than sending without it.
3. The task's `taskDescription` is `<itemID>#<attempt>`, so a completion that arrives after a re-arm is matched to the attempt that produced it; stale ones are ignored. Re-arming cancels exactly the old attempt, and reconciliation on foreground only re-arms attempts that did not change while it awaited the session's task list, so one item never has two live uploads.
4. On completion `WebhookRetryPolicy` decides:
   - 2xx: delivered, item removed
   - network error, 408, 429, 5xx: retry. `Retry-After` (seconds or HTTP date) is honored on 429/503, otherwise backoff 30s, 2m, 10m, 30m, then hourly
   - 3xx, or a response that came from another URL than the one requested: stop and record the failure (see Redirects)
   - any other status, or a malformed URL: stop and record the failure
   - older than 24 hours: dropped and recorded as failed
5. While any upload is in flight, the service holds background time (`BackgroundTaskService`, about 30 seconds), so a send that starts as the app leaves the foreground can finish. When the time runs out the app is suspended. The upload then completes or fails after the app resumes, and on a relaunch `resume()` re-arms it.
6. Retries run only while the app runs. A timer starts the earliest pending retry when it is due. A retry that comes due while the app is suspended or not running waits until the next launch or foreground.

`AppDelegate.didFinishLaunching` and the scene becoming active call `activate()`, which re-arms items whose task disappeared and starts what is due. Editing a webhook's URL or token re-arms its pending items; disabling or deleting it drops them.

The bearer token is read from the Keychain per attempt and lives only in the in-flight request. It is never written outside the Keychain, logged or sent to analytics.

## Redirects

Webhook requests must reach only the exact https URL the user entered. Because the app sets `NSAllowsArbitraryLoads`, ATS would not stop a redirect to plain http.

- Every webhook request (deliveries and Send Test) runs in a default or ephemeral session whose delegate refuses every redirect (`WebhookRedirectRefuser`, and the same refusal in the transport's delegate). The 3xx response is the result: delivery stops with "Redirects are not followed", and nothing is sent to the redirect target. The token is never sent there either.
- As a second line of defense, the transport compares the response URL with the requested one (`WebhookRedirects.isSameEndpoint`). A mismatch is recorded as failed, never as delivered.
- Deliveries deliberately do not use a background `URLSession`. Per Apple's documentation, `urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)` is called only for default and ephemeral sessions, and background sessions follow redirects automatically. Measured on the iOS 26.5 simulator, a background session followed a 307 or 308 and sent the body again to another host or over plain http. It removed the `Authorization` header and kept the other headers. The price of refusing redirects is that retries no longer run while the app is suspended or not running.

## Text content

Each webhook picks which text it receives (`WebhookTextContent`, the "Text to Send" picker in the webhook sheet). It mirrors the Markdown export choice:

| Option | `textContent` | `text` | `rawText` | `aiModel` |
|--------|---------------|--------|-----------|-----------|
| Both (default) | `both` | last AI-processed text, or the transcript when no processing ran | the transcript, when it differs from `text` | when processing ran |
| Last Processed Only | `processed` | last AI-processed text, or the transcript when no processing ran | never | when processing ran |
| Original Only | `original` | the transcript | never | never |

"Last processed" is `Transcription.enhancedText`, the latest AI output. `textContent` says which option the webhook uses, not whether AI processing ran: with `processed` and no processing, `text` is the transcript. Check `aiModel`, which is present only when `text` is AI output. Webhooks saved before the option existed, and unknown values written by a newer version, decode as Both, which is the behavior before the option. The option is applied when an item is queued, so changing it does not rewrite pending items. Send Test uses the option currently in the form.

## Recording time

`createdAt` is when the note was created (transcribed). `recordedAt` is when the audio was recorded, so a receiver can file a note under the real meeting time even when the recording reached VivaDicta hours later. It is stored as `Transcription.recordedAt` when the note is saved, so automatic sends, retries and manual re-sends all carry it.

| Route | Source of `recordedAt` |
|-------|------------------------|
| In-app recording, keyboard recordings, App Intents | Recording start (`RecordViewModel.startCaptureAudio`) |
| Apple Watch | The recording start the watch sends (`recordingStartedAt`); for older watch builds, the stop time minus the recorded length (`PhoneWatchConnectivityService.recordingStart(metadata:)`). Carried through `BackgroundWorkItem` when processing is deferred |
| Share and action extensions | `ImportedAudioRecordingDate.read(from:)` on the file the share sheet hands over, before it is copied. The date travels to the app through the App Group (`setPendingRecordedAt`) |
| File import and "Open With" | The original's file creation date is read before the copy; the media metadata is read from the copy (same bytes) before downsampling (`RecordingTime.imported`) |

For imported files the media's own creation metadata comes first, then the file creation date. Within the media, the keys recorders write (QuickTime and ID3 recording dates, QuickTime and ISO user data dates) rank first, then `AVAsset.creationDate`, then `©day`. `AVAsset.creationDate` can be the container's creation time, which a re-export resets, so an export a day after the recording must not win over the recorder's date. `©day` is last because on music it is a release date. The first date that passes the trust check is used. Only full timestamps count: a bare year or day is ignored.

A date is trusted only when it is after 2000-01-01 (zeroed headers produce 1904 or 1970) and at least 60 seconds before the import. A date at or near the import time means it was lost on the way in (the share sheet or a copy stamped the file) and is not sent. `recordedAt` is omitted when nothing trustworthy is found. It is also omitted for orphaned audio recovered at launch, live translation sessions, and notes created before this field existed. It is never a guess.

## Contract v1

`POST`, `Content-Type: application/json; charset=utf-8`

Headers: `Authorization: Bearer <token>` (when set), `Idempotency-Key: <transcription UUID>`, `User-Agent: VivaDicta/<version>`

```json
{
  "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
  "text": "Final text (AI output when processing ran)",
  "rawText": "Original transcript, only when it differs from text",
  "textContent": "both",
  "mode": "Meeting",
  "createdAt": "2026-11-06T09:00:00+01:00",
  "recordedAt": "2026-11-05T14:30:00+01:00",
  "duration": 2712.4,
  "language": "en",
  "source": "shareExtension",
  "transcriptionModel": "Parakeet V3",
  "aiModel": "model-id",
  "app": "VivaDicta",
  "appVersion": "3.13.0",
  "platform": "iOS"
}
```

Unknown values are omitted, never `null`. `id` is stable across retries and manual re-sends, so receivers can deduplicate on it. Text is never truncated. Success is any 2xx; the response body is only shown by "Send test".

`textContent` (always present) and `recordedAt` (only when known) were added to v1 without changing any other field. Receivers that ignore them keep working: with the default option, `text` and `rawText` are exactly what they were before.

## Settings

Settings → Integrations → Webhooks lists webhooks with their last delivery result, and opens an add / edit sheet with the "Text to Send" picker and "Send test" (posts a sample payload to the URL, token and text option in the form, before saving). The sample has both an original and a processed text and a `recordedAt` one hour before the send, so the receiver sees every field. Each mode's editor has a Webhook picker once at least one webhook exists.

## Tests

`WebhookPayloadTests`, `VivaModeWebhookDecodingTests`, `WebhookRetryPolicyTests`, `WebhookRedirectsTests`, `WebhookDeliveryServiceTests` (real `URLSession` through `WebhookURLProtocolStub`, including redirect, text content and Send Test cases), `WebhookStoreTests`, `WebhookTextContentPayloadTests`, `WebhookDefinitionTextContentDecodingTests`, `RecordingTimeTests`, `WatchRecordingStartTests`. In the AppGroup module: `ImportedAudioRecordingDateTests` (trust rule, source order, real .m4a files with recorder metadata) and the pending date round trip in `AppGroupCoordinatorStateTests`.
