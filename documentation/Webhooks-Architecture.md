# Webhooks Architecture

## Overview

After a recording is transcribed and AI-processed, VivaDicta can POST the result as JSON to a user-configured webhook. Each mode picks one webhook or none. Typical receivers are n8n, Zapier, Make, or the user's own server.

Delivery goes through a persistent outbox and an in-process `URLSession` that refuses redirects. Sends and retries run while the app runs, and the app holds background time while an upload is in flight. A failing webhook never blocks or delays transcription, the Obsidian hand-off or folder export.

## Components

| Type | File | Role |
|------|------|------|
| `WebhookDefinition` | `Services/Webhooks/WebhookDefinition.swift` | Name, https URL, enabled flag, `hasBearerToken`. Also `WebhookURLValidator` and `WebhookDeliveryStatus` |
| `WebhookStore` | `Services/Webhooks/WebhookStore.swift` | Definitions and last status per webhook (app-private UserDefaults). Bearer tokens in the Keychain as `AfterFirstUnlockThisDeviceOnly` items, so a send that runs while the phone is locked (for example a watch recording processed in the background) can read them |
| `WebhookPayloadBuilder` | `Services/Webhooks/WebhookPayload.swift` | Pure payload composition and the request headers (`WebhookRequestBuilder`) |
| `WebhookRetryPolicy` | `Services/Webhooks/WebhookRetryPolicy.swift` | Pure retry and stop rules, backoff, `Retry-After`, max age |
| `WebhookOutboxStorage` | `Services/Webhooks/WebhookOutbox.swift` | `Application Support/Webhooks/outbox.json` plus one body file per item |
| `URLSessionWebhookTransport` | `Services/Webhooks/WebhookTransport.swift` | File-backed upload tasks in an ephemeral, in-process session that refuses redirects |
| `WebhookRedirects` | `Services/Webhooks/WebhookRedirects.swift` | Redirect rules: the Send Test session, `WebhookRedirectRefuser`, and the check that a response came from the requested URL |
| `WebhookDeliveryService` | `Services/Webhooks/WebhookDeliveryService.swift` | Orchestrates enqueue, delivery, retries, reconciliation and manual sends |

`VivaMode.webhookID` holds the per-mode choice. It is decoded with `decodeIfPresent`, so modes saved by older versions still load. Deleting a webhook clears it from every mode (`AIService.clearWebhookReferences(to:)`) and drops its pending items.

Modes and webhook definitions are device-local (App Group / app-private UserDefaults). Nothing here touches CloudKit or SwiftData.

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

## Contract v1

`POST`, `Content-Type: application/json; charset=utf-8`

Headers: `Authorization: Bearer <token>` (when set), `Idempotency-Key: <transcription UUID>`, `User-Agent: VivaDicta/<version>`

```json
{
  "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
  "text": "Final text (AI output when processing ran)",
  "rawText": "Original transcript, only when it differs from text",
  "mode": "Meeting",
  "createdAt": "2026-11-05T09:00:00+01:00",
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

## Settings

Settings → Integrations → Webhooks lists webhooks with their last delivery result, and opens an add / edit sheet with "Send test" (posts a sample payload to the URL and token in the form, before saving). Each mode's editor has a Webhook picker once at least one webhook exists.

## Tests

`WebhookPayloadTests`, `VivaModeWebhookDecodingTests`, `WebhookRetryPolicyTests`, `WebhookRedirectsTests`, `WebhookDeliveryServiceTests` (real `URLSession` through `WebhookURLProtocolStub`, including redirect and Send Test cases), `WebhookStoreTests`.
