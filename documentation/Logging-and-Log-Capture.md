# Logging and Log Capture

## Overview

VivaDicta uses Apple's unified logging system (`os.Logger`) for all log output. Every log call goes through `LoggerExtension.swift` which provides category-based loggers and optional `print()` output for device debugging.

## Logging in Code

### Logger Setup

```swift
import os

let logger = Logger(category: .recordViewModel)

logger.logInfo("Recording started")
logger.logError("Failed to start recording: \(error)")
logger.logWarning("Audio level unusually high")
logger.logDebug("Buffer size: \(size)")
```

### Categories

All categories are defined in `LoggerExtension.swift` via the `LogCategory` enum. Each category maps to a subsystem + category pair in OSLog:

- **Subsystem**: `com.antonnovoselov.VivaDicta` (shared across main app and all extensions)
- **Category**: e.g., `RecordViewModel`, `KeyboardExtension`, `AppGroupCoordinator`

### Log Levels

| Method | OSLog Level | When to Use |
|--------|-------------|-------------|
| `logDebug()` | Debug | Verbose details, buffer sizes, format info |
| `logInfo()` | Info | Normal flow events, state changes |
| `logNotice()` | Notice | Notable events worth attention |
| `logWarning()` | Warning | Unexpected but recoverable situations |
| `logError()` | Error | Failures, always persisted by OS |

### ENABLE_PRINT_LOGS

`LoggerExtension.swift` checks `ProcessInfo.processInfo.environment["ENABLE_PRINT_LOGS"]`. When set to `"1"`, every `logInfo()` / `logError()` etc. also calls `print()` to stdout. This is needed because `devicectl --console` only captures stdout, not OSLog.

- **Running from Xcode**: env var not set, no duplicate prints
- **Running via `/start-logs-device`**: env var set, prints visible in terminal
- **Running normally on device**: env var not set, logs only in OSLog

## Log Capture Methods

### Simulator

| Command | Description |
|---------|-------------|
| `/start-logs` | Start capturing simulator logs |
| `/stop-logs` | Stop capture, show summary |

### Physical Device — Real-Time (Main App Only)

| Command | Description |
|---------|-------------|
| `/start-logs-device` | Launch app on device via `devicectl` with `ENABLE_PRINT_LOGS=1` |
| `/stop-logs-device` | Stop capture |

- Captures **main app process only** (not keyboard/widget extensions)
- Logs stream in real-time in the terminal
- Restarts the app on the device
- Saves to `logs/device-YYYYMMDD-HHMMSS.log`

### Physical Device — Structured (All Processes)

| Command | Description |
|---------|-------------|
| `/start-logs-device-structured` | Record timestamp for later collection |
| `/stop-logs-device-structured` | Collect all logs since timestamp via `sudo log collect` |

- Captures **all processes**: main app, keyboard extension, widget, share extension
- Uses OSLog directly — no need for `ENABLE_PRINT_LOGS`
- Requires `sudo` password for `log collect`
- Saves `.logarchive` (openable in Console.app) and filtered `.txt`
- Saves to `logs/device_YYYYMMDD_HHMMSS.txt` and `logs/vivadicta_device_YYYYMMDD_HHMMSS.logarchive`

**Use this method when debugging interaction between main app and extensions** (e.g., keyboard text processing, recording from keyboard, widget triggers).

### When to Use Which

| Scenario | Method |
|----------|--------|
| Debugging main app in simulator | `/start-logs` + `/stop-logs` |
| Debugging main app on device, real-time | `/start-logs-device` |
| Debugging keyboard extension | `/start-logs-device-structured` |
| Debugging main app + extension interaction | `/start-logs-device-structured` |
| Post-mortem analysis of a device issue | `/start-logs-device-structured` |

## Analyzing Collected Logs

### Text Logs

```bash
# View latest log file
cat logs/device_YYYYMMDD_HHMMSS.txt

# Search for specific patterns
grep "TextProcessor" logs/device_*.txt
grep "error" logs/device_*.txt
```

### Log Archives

```bash
# Open in Console.app (GUI)
open logs/vivadicta_device_*.logarchive

# Filter by category
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta" AND category == "RecordViewModel"' \
  --info --style compact

# Filter by process (keyboard extension only)
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta" AND process == "VivaDictaKeyboard"' \
  --info --style compact

# Export to JSON
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta"' \
  --info --style json > logs/device_logs.json
```

## Key Files

| File | Purpose |
|------|---------|
| `VivaDicta/Utilities/LoggerExtension.swift` | `Logger` extension with categories and conditional print |
| `scripts/launch_device.sh` | Launches app on device with `ENABLE_PRINT_LOGS=1` |
| `scripts/collect_device_logs.sh` | Collects device logs via `sudo log collect` |
