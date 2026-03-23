---
name: start-logs-device
description: Launch VivaDicta on a physical iOS device with print logging enabled for real-time console capture
disable-model-invocation: true
---

# start-logs-device

## Task

Launch VivaDicta on a physical iOS device with print logging enabled to capture real-time console output including all emojis and log messages.

## Instructions

1. **Create logs directory** (if it doesn't exist):
   ```bash
   mkdir -p logs
   ```

2. **Launch the script in the background**:
   ```bash
   ./scripts/launch_device.sh
   ```

   Use `run_in_background: true` when calling via Bash tool.

   This will:
   - Display logs in the console in real-time
   - Save logs to `logs/device-YYYYMMDD-HHMMSS.log` with timestamp

3. **What this does**:
   - Launches VivaDicta on the connected physical device
   - Sets `ENABLE_PRINT_LOGS=1` environment variable to enable print statements
   - Captures stdout/stderr output in real-time
   - Shows all log messages with emojis (📱, 🎬, 🦜, ✅, etc.)
   - Terminates any existing instance of the app before launching

## Expected Output

You should see output like:
```
Launched application with com.antonnovoselov.VivaDicta bundle identifier.
Waiting for the application to terminate…
📱 Preload skipped: Current mode doesn't use WhisperKit (uses parakeet)
🎬 App became active - checking for stale Live Activity
```

## Important Notes

- **Device UDID**: The script is configured for device `00008130-001250203C92001C` (iPhone 15 Pro Max Anton)
  - If using a different device, update the `--device` parameter in `./scripts/launch_device.sh`

- **Device Requirements**:
  - Device must be connected via USB or network
  - Device must be trusted and paired with the Mac
  - Works with iOS 17+ devices (devicectl requires iOS 17+)

- **Environment Variable**:
  - `ENABLE_PRINT_LOGS=1` enables print statements alongside Logger calls
  - Without this variable, only OSLog statements are captured (not visible in --console)
  - Print statements are conditionally enabled via LoggerExtension.swift

- **How It Works**:
  - LoggerExtension checks `ProcessInfo.processInfo.environment["ENABLE_PRINT_LOGS"]`
  - When set to "1": both Logger.info() AND print() execute
  - When not set: only Logger.info() executes (no print statements)
  - This avoids duplicate logs in Xcode while enabling console capture on device

- **Stopping the Log Stream**:
  - Press Ctrl+C to stop capturing logs
  - The app will continue running on the device

## Troubleshooting

- **Device not found**: Verify device is connected with `xcrun xctrace list devices`
- **Permission denied**: Ensure device is trusted in System Settings
- **No logs appearing**: Check that ENABLE_PRINT_LOGS is set correctly in the JSON
- **App won't launch**: Try rebuilding and installing via Xcode first

## Log File Management

**Log files are automatically saved to**: `./logs/device-YYYYMMDD-HHMMSS.log`

**View recent logs**:
```bash
ls -lt logs/device-*.log | head -5
```

**View a specific log file**:
```bash
cat logs/device-20251016-213500.log
```

**Search logs for specific patterns**:
```bash
grep "📱" logs/device-*.log  # Find all lines with 📱 emoji
grep -i "error" logs/device-*.log  # Find all error messages
```

**Clean up old logs** (optional):
```bash
# Remove logs older than 7 days
find logs -name "device-*.log" -mtime +7 -delete
```

## Related

- LoggerExtension.swift - Contains the conditional print logic
- All logger calls use `.logInfo()`, `.logError()`, etc. wrapper methods
- When running from Xcode: no duplicate logs (print is disabled)
- When running from devicectl: print logs are visible in console
