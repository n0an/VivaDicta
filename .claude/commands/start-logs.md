# start-logs

## Task

Start a log capture session for VivaDicta app running in the iOS Simulator. This command captures structured logs from the running app in real-time and saves them to a file.

## Instructions

1. **Create logs directory** (if it doesn't exist):
   ```bash
   mkdir -p logs
   ```

2. **Launch the script in the background**:
   ```bash
   ./scripts/launch_simulator.sh
   ```

   Use `run_in_background: true` when calling via Bash tool.

   This will:
   - Automatically detect the booted simulator
   - Stream logs in real-time to console
   - Save logs to `logs/sim-YYYYMMDD-HHMMSS.log` with timestamp
   - Capture all log levels (debug, info, error, etc.)
   - Filter only VivaDicta subsystem logs

3. **Report to the user**:
   - Confirm that log capture has started
   - Display the log file path
   - Remind the user: "Log capture is active. Interact with your app, then use `/stop-logs` to stop and view the captured logs"
   - Note: The app continues running and does NOT need to be relaunched

## Expected Output

You should see logs streaming in real-time:
```
Filtering the log data using "subsystem == "com.antonnovoselov.VivaDicta""
Timestamp                       Thread     Type        Activity             PID    TTL
2025-10-16 21:35:17.123456-0700 0x123456   Default     0x0                  12345  0    VivaDicta: [AppState] 📱 Preload skipped: Current mode doesn't use WhisperKit (uses parakeet)
2025-10-16 21:35:17.234567-0700 0x123456   Default     0x0                  12345  0    VivaDicta: [AppState] 🎬 App became active - checking for stale Live Activity
```

## Important Notes

- **VivaDicta uses structured logging (os_log/Logger)** - all logs are captured
- The app will NOT be relaunched - it keeps running with its current state
- The user can interact with the app manually while logs are being captured
- Press `Ctrl+C` or use `/stop-logs` to stop capturing

## What Gets Captured

- ✅ All Logger.info(), .debug(), .error(), .warning(), .notice() calls
- ✅ Emojis and special characters preserved
- ✅ Category information (AppState, AudioPrewarmManager, etc.)
- ✅ Timestamps and thread information
- ❌ Print statements (NOT captured by log stream - only OSLog)

## Troubleshooting

- **No simulator booted**: The script will exit with an error if no simulator is booted. Launch a simulator first.
- **No logs appearing**: Ensure the app is running and generating logs
- **Permission denied**: Check that the simulator is fully booted

## Technical Details

- Uses `xcrun simctl spawn` to run `log stream` inside the simulator
- Filters by subsystem to show only VivaDicta logs
- Logs are saved with timestamps to avoid overwriting
- Background process continues until stopped

## Related

- `/stop-logs` - Stop log capture and view summary
- `logs/sim-*.log` - Timestamped simulator log files
