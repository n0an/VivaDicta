---
name: start-logs-device-structured
description: Record timestamp for structured device log collection from physical iOS device (captures all processes including extensions)
disable-model-invocation: true
---

# start-logs-device-structured

## Task

Prepare for structured device log capture by recording the current timestamp and target device UDID.

## Instructions

1. Find a connected physical iPhone:
   ```bash
   xcrun xctrace list devices | grep iPhone | grep -v Simulator | head -1
   ```
2. Ensure the temp directory exists:
   ```bash
   mkdir -p llmtemp
   ```
3. Record the current timestamp:
   ```bash
   date '+%Y-%m-%d %H:%M:%S' > llmtemp/.device-log-start-time
   ```
4. Save the selected device UDID to:
   ```bash
   echo "<UDID>" > llmtemp/.device-log-udid
   ```
5. Report the start time and device UDID to the user.
6. Tell the user to reproduce the issue, then use the `stop-logs-device-structured` skill.

## Notes

- This skill does not start a background process. It only records state for later collection.
- The app should already be installed and runnable on the target device.
- The follow-up collection step uses `sudo log collect`, so the user will need interactive sudo access.

## Related

- [`stop-logs-device-structured`](../stop-logs-device-structured/SKILL.md)
- [`ios-log-capture`](../ios-log-capture/SKILL.md)
