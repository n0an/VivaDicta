# Firebase Analytics Events - VivaDicta

## Overview

VivaDicta uses Firebase Analytics to track key user interactions and app behavior. This document lists all custom analytics events implemented in the app.

## Automatic Events (No Code Required)

Firebase automatically tracks these events:
- `first_open` - First time app is opened
- `session_start` - Each session start
- `app_update` - App version updates
- `user_engagement` - Time spent in app

Automatic user properties:
- Device model
- OS version
- App version
- Country/region
- Language

---

## Custom Events

### 1. `unrecognized_host_app`

**When:** User invokes keyboard from an app that doesn't have a URL scheme mapped.

**Location:** `VivaDictaApp.swift` - `attemptReturnToHost()`

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `bundle_id` | String | The bundle ID of the host app |

**Purpose:** Track which apps users want to use with the keyboard but aren't supported yet. Use this data to prioritize adding URL schemes for popular apps.

**How to find in Firebase Console:**
1. Go to Firebase Console → Analytics → Events
2. Find `unrecognized_host_app`
3. Click to see the `bundle_id` parameter breakdown
4. Sort by count to see most requested apps

---

### 2. `keyboard_session_started`

**When:** User taps mic button in keyboard and app opens via deep link.

**Location:** `VivaDictaApp.swift` - `handleDeepLink()`

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `host_bundle_id` | String | Bundle ID of the app where keyboard was used |

**Purpose:** Track keyboard usage and which apps users dictate into most frequently.

---

### 3. `model_downloaded`

**When:** User successfully downloads a transcription model.

**Location:** `ModelDownloadManager.swift`

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `model_name` | String | Display name of the model |
| `model_type` | String | Either "parakeet" or "whisperkit" |

**Purpose:** Track which models are most popular and on-device vs cloud preference.

---

### 4. `onboarding_completed`

**When:** User finishes the onboarding flow.

**Location:** `VivaDictaApp.swift`

**Parameters:** None

**Purpose:** Track onboarding completion rate.

---

## Future Events (Not Yet Implemented)

Due to compiler complexity limits in `RecordViewModel.swift`, these events need alternative implementation approaches:

| Event | Description | Status |
|-------|-------------|--------|
| `transcription_completed` | When transcription finishes successfully | Planned |
| `transcription_error` | When transcription fails | Planned |
| `ai_enhancement_used` | When AI improves transcription text | Planned |

---

## Viewing Analytics Data

### Real-time Data (Last 30 Minutes Only)
Firebase Console → Analytics → Dashboard → click on an event
- The right-side panel shows "EVENTS IN LAST 30 MINUTES" with parameter values
- This is the ONLY place that shows parameter values without custom dimension registration
- Limited to the last 30 minutes — not useful for historical analysis

Firebase Console → Analytics → Realtime
- Shows events within last 30 minutes
- Useful for testing new events

### Historical Event Counts (No Parameter Breakdown)
Firebase Console → Analytics → Events
- Full event list with counts, total users, etc.
- Covers the selected date range (e.g., last 28 days)
- Clicking an event shows the Dashboard view with the same real-time-only parameter panel
- Does NOT provide historical parameter breakdowns on the Spark (free) plan

### Historical Parameter Breakdown (Requires Custom Dimensions)

To see parameter values (like `bundle_id`) in historical reports, you MUST register them as Custom Dimensions first. This was done on 2026-02-24.

**Registered Custom Dimensions:**
| Dimension Name | Scope | Event Parameter | Registered Date |
|---|---|---|---|
| Bundle ID | Event | `bundle_id` | 2026-02-24 |
| Host Bundle ID | Event | `host_bundle_id` | 2026-02-24 |

**Important:** Custom dimensions only collect data GOING FORWARD from the registration date. Historical events before registration will show as "(not set)".

### How to View Parameter Data in Google Analytics Explore

Once custom dimensions are registered and new data has been collected (allow 24-48 hours):

1. Firebase Console → click **"View more in Google Analytics"** (top-right)
2. In Google Analytics, go to **Explore** (left sidebar)
3. Open the saved exploration **"Unrecognized Host Apps"** (or create a new Blank exploration)
4. If creating new:
   - **Variables panel (left):**
     - DIMENSIONS: click **+** → add **Bundle ID** (Custom tab), **Host Bundle ID** (Custom tab), **Event name** (Predefined tab)
     - METRICS: click **+** → add **Event count**
   - **Settings panel (middle):**
     - ROWS: drag **Bundle ID**
     - VALUES: drag **Event count**
     - FILTERS: **Event name** exactly matches `unrecognized_host_app`
     - SHOW ROWS: set to 50
5. The table will show all unrecognized bundle IDs sorted by event count
6. To see keyboard usage by app, create a second tab with:
   - ROWS: **Host Bundle ID**
   - VALUES: **Event count**
   - FILTERS: **Event name** exactly matches `keyboard_session_started`

### BigQuery Export (Blaze Plan Only)

For full historical parameter data (including events before custom dimension registration), you would need:
1. Upgrade to Firebase Blaze plan (pay-as-you-go)
2. Enable BigQuery Export in Firebase Console → Project Settings → Integrations
3. Query raw event data with SQL, e.g.:
```sql
SELECT
  event_params.value.string_value AS bundle_id,
  COUNT(*) AS event_count
FROM `your-project.analytics_XXX.events_*`,
  UNNEST(event_params) AS event_params
WHERE event_name = 'unrecognized_host_app'
  AND event_params.key = 'bundle_id'
GROUP BY bundle_id
ORDER BY event_count DESC
```

---

## Adding New Host App URL Schemes

When new bundle IDs appear in the analytics:

1. Check the Explore report for the most common unrecognized bundle IDs
2. Find the app's URL scheme (search online or check the app's Info.plist)
3. Add the mapping to `VivaDictaApp.swift` → `getURLSchemeForBundleId()` → `knownSchemes` dictionary
4. The app must also declare the scheme in its `Info.plist` under `LSApplicationQueriesSchemes` for `canOpenURL()` to work

---

## Best Practices

1. **Event names:** Use snake_case (e.g., `keyboard_session_started`)
2. **Parameter names:** Use snake_case (e.g., `bundle_id`)
3. **Parameter values:** Keep concise, avoid PII
4. **Testing:** Use DebugView in Firebase Console for real-time testing
5. **Limits:** Max 500 distinct events, 25 parameters per event
6. **Custom dimensions:** Register event parameters as custom dimensions EARLY — you lose historical data if you register late