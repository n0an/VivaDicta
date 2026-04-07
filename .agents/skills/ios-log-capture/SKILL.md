---
name: ios-log-capture
description: Reference guide for capturing console logs from iOS apps in Simulator or physical devices using native logging tools
---

# iOS Log Capture

Use this skill when you need to capture console logs from iOS apps running in Simulator or on physical devices for debugging, testing, or monitoring purposes.

## Related Skills

- See [`start-logs`](../start-logs/SKILL.md) and [`stop-logs`](../stop-logs/SKILL.md) for simulator structured logging
- See [`start-logs-device`](../start-logs-device/SKILL.md) and [`stop-logs-device`](../stop-logs-device/SKILL.md) for real-time device print logging
- See [`start-logs-device-structured`](../start-logs-device-structured/SKILL.md) and [`stop-logs-device-structured`](../stop-logs-device-structured/SKILL.md) for full device log archives
- See [`xcodebuild-testing`](../xcodebuild-testing/SKILL.md) for running tests that may require log analysis
- See [`axe-simulator-control`](../axe-simulator-control/SKILL.md) for automating simulator interactions before capturing logs

## Logging Methods

### 1. Simulator Structured Logging

Use `start-logs` to begin capture and `stop-logs` to summarize or filter the latest simulator log file.

Best for:
- Fast local debugging
- Real-time monitoring while the app stays open
- Reviewing `Logger` output with timestamps, categories, and metadata

How it works:
1. `start-logs` runs `./scripts/launch_simulator.sh` in a long-lived shell session
2. `xcrun simctl spawn ... log stream` writes to `logs/sim-YYYYMMDD-HHMMSS.log`
3. `stop-logs` stops the active stream and summarizes or filters the latest file

Captures:
- `Logger` output with subsystem filtering
- Timestamps, categories, and thread metadata
- Emojis and special characters

Does not capture:
- `print()` output

### 2. Device Print Logging

Use `start-logs-device` to launch the app on a physical device with `ENABLE_PRINT_LOGS=1`, then use `stop-logs-device` to stop the session and inspect the newest log file.

Best for:
- Capturing `print()` output on real hardware
- Device-only issues where Console or Simulator does not reproduce the bug
- Reviewing stdout and stderr in real time

How it works:
1. `start-logs-device` runs `./scripts/launch_device.sh` in a long-lived shell session
2. `xcrun devicectl device process launch --console` streams output into `logs/device-YYYYMMDD-HHMMSS.log`
3. `stop-logs-device` stops the active session and summarizes the newest file

Captures:
- `print()` output enabled through `ENABLE_PRINT_LOGS=1`
- stdout and stderr
- Any mirrored log text emitted by `LoggerExtension`

### 3. Device Structured Logging

Use `start-logs-device-structured` to record a start timestamp and device UDID, then use `stop-logs-device-structured` to guide the user through running `./scripts/collect_device_logs.sh`.

Best for:
- Production-style debugging
- Full `.logarchive` capture with later re-analysis in Console.app
- Rich filtering by subsystem, category, and message type

How it works:
1. `start-logs-device-structured` stores the current timestamp and device UDID in `llmtemp/`
2. The user reproduces the issue on device
3. `stop-logs-device-structured` asks the user to run `./scripts/collect_device_logs.sh`
4. The script runs `sudo log collect`, writes `logs/vivadicta_device_*.logarchive`, and extracts `logs/device_*.txt`

Captures:
- Full structured logs with metadata
- Reopenable `.logarchive` artifacts
- A filtered text export for quick analysis

## Quick Start

### Simulator

1. Run the `start-logs` skill.
2. Interact with the app in the Simulator.
3. Run the `stop-logs` skill.
4. Optionally pass a filter such as `errors`, `warnings`, `all`, or a search term.

### Device Print Logging

1. Run the `start-logs-device` skill.
2. Reproduce the issue on the connected device.
3. Stop the active shell session or otherwise end the `devicectl` stream.
4. Run the `stop-logs-device` skill.

### Device Structured Logging

1. Run the `start-logs-device-structured` skill.
2. Reproduce the issue on the connected device.
3. Run the `stop-logs-device-structured` skill.
4. Follow the prompt to run `./scripts/collect_device_logs.sh` interactively.

## Manual Analysis Commands

```bash
# Inspect recent simulator logs
ls -lt logs/sim-*.log | head -5
grep -i "error\\|fault" logs/sim-*.log
grep "\\[AppState\\]" logs/sim-*.log

# Inspect recent device print logs
ls -lt logs/device-*.log | head -5
grep -i "error" logs/device-*.log

# Inspect structured device archives
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta"'
```

## Notes

- VivaDicta primarily uses structured logging through `Logger`, so simulator logging is usually the fastest high-signal option.
- Device print logging depends on `ENABLE_PRINT_LOGS=1` and is best for flows where mirrored print output is useful.
- Structured device logging is slower, but it preserves the most context and is best for hard-to-reproduce issues.
- Use the `screenshot` skill to capture visual state while reproducing a bug.
