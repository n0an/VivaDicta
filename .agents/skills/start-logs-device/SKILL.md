---
name: start-logs-device
description: Launch VivaDicta on a physical iOS device with print logging enabled for real-time console capture
disable-model-invocation: true
---

# start-logs-device

## Task

Launch VivaDicta on a connected physical device with print logging enabled and keep the console capture running in a long-lived shell session.

## Instructions

1. Ensure the logs directory exists:
   ```bash
   mkdir -p logs
   ```
2. Run the helper script in a long-lived shell session:
   ```bash
   ./scripts/launch_device.sh
   ```
3. Keep that session alive while the user reproduces the issue on device.
4. Tell the user the output is being written to `logs/device-YYYYMMDD-HHMMSS.log`.
5. Tell the user to use the `stop-logs-device` skill when they want the newest file summarized.

## Notes

- `./scripts/launch_device.sh` uses `xcrun devicectl device process launch --console`.
- The current script targets device UDID `00008130-001250203C92001C`.
- `ENABLE_PRINT_LOGS=1` is set so mirrored print output is visible in the console stream.
- The script terminates any existing app instance before launching a fresh one.
- Works only on supported physical-device setups where `devicectl` is available.

## Related

- [`stop-logs-device`](../stop-logs-device/SKILL.md)
- [`ios-log-capture`](../ios-log-capture/SKILL.md)
