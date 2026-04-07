---
name: start-logs-device-structured
description: Record timestamp for structured device log collection from physical iOS device (captures all processes including extensions)
disable-model-invocation: true
---

# start-logs-device-structured

## Task

Prepare for device log capture by recording the current timestamp. When ready to collect logs, you'll use `/stop-logs-device-structured` which will collect all logs since this timestamp from your physical iOS device.

## Instructions

1. **Get the device UDID**:
   ```bash
   xcrun xctrace list devices | grep iPhone | grep -v Simulator | head -1
   ```
   Extract the UDID from the output (format: `00008130-001250203C92001C`).

2. **Ensure llmtemp directory exists**:
   ```bash
   mkdir -p llmtemp
   ```

3. **Record the start timestamp**:
   ```bash
   date '+%Y-%m-%d %H:%M:%S' > llmtemp/.device-log-start-time
   ```

4. **Save the device UDID**:
   ```bash
   echo "<UDID>" > llmtemp/.device-log-udid
   ```

5. **Report to the user**:
   - Confirm that log capture session has been initialized
   - Display the device name and UDID
   - Display the start timestamp prominently
   - Instruct the user: "Start timestamp recorded. Interact with your app on the device, then use `/stop-logs-device-structured` to collect all logs since this time."
   - Note: `/stop-logs-device-structured` will prompt for your sudo password to collect the logs
   - The app should already be running on the device

## Important Notes

- **No background process** - this just records a timestamp
- The actual log collection happens when you run `/stop-logs-device-structured`
- **Requires sudo** - `log collect` needs elevated privileges to access device logs
- The device must be connected via USB or network
- The device must be trusted and paired with the Mac
- Works with iOS 12+ devices

## How It Works

1. `start-logs-device-structured` - Records current timestamp
2. *You interact with your app*
3. `stop-logs-device-structured` - Collects all logs from the device since the recorded timestamp using `sudo log collect`

## Technical Details

- Uses native `log collect` command (most reliable method)
- Filters logs by subsystem: `com.antonnovoselov.VivaDicta`
- Creates a `.logarchive` file that can be analyzed with `log show`
- Supports timestamp-based log collection

## Additional Resources

- [iOS Log Capture Skill](../ios-log-capture/SKILL.md) - Complete log capture reference
- Apple Developer: `man log` - log command documentation
