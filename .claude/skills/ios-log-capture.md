# iOS Log Capture

Use this skill when you need to capture console logs from iOS apps running in Simulator or on physical devices for debugging, testing, or monitoring purposes.

## Related Skills

- See [`xcodebuild-testing.md`](./xcodebuild-testing.md) for running tests that may require log analysis
- See [`axe-simulator-control.md`](./axe-simulator-control.md) for automating simulator interactions before capturing logs

## Related Commands

- `/start-logs` - Start simulator log capture (structured logging)
- `/stop-logs` - Stop simulator log capture and view summary
- `/start-logs-device` - Launch app on device with print logging enabled
- `/stop-logs-device` - Stop device log capture (print-based)
- `/start-logs-device-structured` - Record timestamp for structured device log collection
- `/stop-logs-device-structured` - Collect structured device logs since timestamp (requires sudo)

## Skill Flow

- Example queries:
  - "capture logs from the simulator"
  - "start logging the app in simulator"
  - "get console output from the running app"
  - "capture logs from physical iPhone"
  - "debug this issue by looking at logs"
- Notes:
  - Uses native iOS logging tools (`log stream`, `log collect`, `devicectl`)
  - **VivaDicta uses structured logging (os_log/Logger)** - all logs include emojis and metadata
  - Simulator logs are captured in real-time to timestamped files in `logs/` directory
  - Device logs support both print-based (`devicectl`) and structured (`log collect`) approaches

## Overview of Logging Methods

### Simulator Log Capture (Recommended for VivaDicta)

**Method:** Native `log stream` via `xcrun simctl spawn`

**Commands:** `/start-logs` and `/stop-logs`

**Best for:**
- Quick development iteration
- Real-time log monitoring
- Structured logging with categories and emojis
- No app relaunch required

**How it works:**
1. `/start-logs` - Spawns a background log stream process
2. App continues running - no restart needed
3. Logs are filtered by subsystem (`com.antonnovoselov.VivaDicta`)
4. Logs saved to `logs/sim-YYYYMMDD-HHMMSS.log`
5. `/stop-logs` - Terminates process and shows summary

**Captures:**
- ✅ All `Logger.info()`, `.debug()`, `.error()`, `.warning()`, `.notice()` calls
- ✅ Emojis and special characters
- ✅ Category information (AppState, RecordViewModel, etc.)
- ✅ Timestamps and thread information
- ❌ Print statements (use device print-based method instead)

### Device Log Capture - Print-Based

**Method:** `devicectl device process launch --console`

**Commands:** `/start-logs-device` and `/stop-logs-device`

**Best for:**
- Capturing print statements
- Testing on real hardware
- When LoggerExtension with `ENABLE_PRINT_LOGS=1` is used

**How it works:**
1. `/start-logs-device` - Launches app with `ENABLE_PRINT_LOGS=1` environment variable
2. LoggerExtension conditionally executes print statements
3. stdout/stderr captured to `logs/device-YYYYMMDD-HHMMSS.log`
4. `/stop-logs-device` - Terminates and shows summary

**Captures:**
- ✅ Print statements (when `ENABLE_PRINT_LOGS=1` is set)
- ✅ stdout/stderr output
- ✅ Emojis in print statements
- ❌ Structured os_log metadata (timestamps less precise)

**Important:**
- Requires iOS 17+ (uses `devicectl`)
- Device must be connected and trusted
- Script configured for device UDID `00008130-001250203C92001C` by default

### Device Log Capture - Structured (Advanced)

**Method:** `sudo log collect` with `.logarchive` output

**Commands:** `/start-logs-device-structured` and `/stop-logs-device-structured`

**Best for:**
- Production debugging
- Complete log archive with full metadata
- Advanced filtering and analysis
- Sharing logs for bug reports

**How it works:**
1. `/start-logs-device-structured` - Records timestamp and device UDID
2. User interacts with app (app should already be running)
3. `/stop-logs-device-structured` - Creates collection script
4. **User manually runs script** (requires sudo password)
5. Script collects logs via `sudo log collect` and extracts VivaDicta logs

**Captures:**
- ✅ Complete structured logs with all metadata
- ✅ Can be opened in Console.app
- ✅ Supports rich predicates for filtering
- ✅ Full timestamps and categories
- ✅ Can be re-analyzed later

**Important:**
- Requires sudo password (interactive)
- Works with iOS 12+
- Creates `.logarchive` files for later analysis
- More comprehensive but slower than other methods

## Quick Start Guide

### Capture Logs from Simulator

```bash
# Start capturing
/start-logs

# Interact with your app in the simulator
# ... perform actions ...

# Stop and view logs
/stop-logs

# Analyze specific patterns
/stop-logs errors          # Show only errors
/stop-logs warnings        # Show only warnings
/stop-logs keyboard        # Search for "keyboard"
/stop-logs all            # Show entire log file
```

### Capture Logs from Physical Device (Print-Based)

```bash
# Launch app with logging enabled
/start-logs-device

# Interact with your app on the device
# ... perform actions ...

# Stop and view logs (press Ctrl+C first)
/stop-logs-device
```

### Capture Structured Logs from Physical Device

```bash
# Record start timestamp
/start-logs-device-structured

# Interact with your app on the device (already running)
# ... perform actions ...

# Collect logs (creates script)
/stop-logs-device-structured

# Run the script manually (in your terminal):
./llmtemp/collect_device_logs.sh

# Analyze the collected logs
cat logs/device_*.txt
open logs/vivadicta_device_*.logarchive  # Opens in Console.app
```

## Common Workflows

### Debug Groq API Error in Simulator

```bash
# Start log capture
/start-logs

# In simulator: Create a very short recording (< 1 second)
# ... tap record, tap stop immediately ...

# Stop and view logs
/stop-logs

# Look for Groq API errors
grep "GroqTranscriptionService" logs/sim-*.log
grep "Audio file is too short" logs/sim-*.log
```

### Monitor App State Transitions

```bash
# Start capture
/start-logs

# Switch app states: background → foreground → background
# ... press home button, reopen app, etc. ...

# Stop and search for state logs
/stop-logs

# View state transitions
grep "App became active" logs/sim-*.log
grep "App resigned active" logs/sim-*.log
```

### Debug Recording Flow on Device

```bash
# Launch with print logging
/start-logs-device

# On device: start recording, speak, stop recording
# ... perform recording workflow ...

# Stop capture (Ctrl+C first)
/stop-logs-device

# Analyze recording states
grep "Recording state changed" logs/device-*.log
grep "RecordViewModel" logs/device-*.log
```

### Collect Complete Device Logs for Bug Report

```bash
# Record start time
/start-logs-device-structured

# Reproduce the bug on device
# ... perform steps that trigger the issue ...

# Collect logs
/stop-logs-device-structured

# Run the script (enter sudo password)
./llmtemp/collect_device_logs.sh

# Share the log archive
# logs/vivadicta_device_*.logarchive can be opened in Console.app
# logs/device_*.txt contains filtered text logs
```

### Compare Simulator vs Device Behavior

```bash
# Capture simulator logs
/start-logs
# ... perform test actions in simulator ...
/stop-logs

# Capture device logs
/start-logs-device
# ... perform same actions on device ...
/stop-logs-device

# Compare
diff logs/sim-*.log logs/device-*.log
```

## Log Analysis

### Common Search Patterns

```bash
# Find all errors
grep -i "error\|fault" logs/sim-*.log

# Find warnings
grep -i "warning" logs/sim-*.log

# Search by category
grep "\[AppState\]" logs/sim-*.log
grep "\[RecordViewModel\]" logs/sim-*.log
grep "\[GroqTranscriptionService\]" logs/sim-*.log

# Find specific emojis
grep "📱" logs/sim-*.log  # Preload/state changes
grep "🎙️" logs/sim-*.log  # Recording
grep "📊" logs/sim-*.log  # Transcription status

# Count log entries
wc -l logs/sim-*.log

# View recent logs
tail -50 logs/sim-*.log

# Follow logs in real-time (while capture is running)
tail -f logs/sim-*.log
```

### Advanced Device Log Analysis

For structured device logs (`.logarchive` files):

```bash
# Open in Console.app (GUI)
open logs/vivadicta_device_*.logarchive

# Filter by message type
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta" AND messageType == "Error"'

# Filter by category
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta" AND category == "RecordViewModel"'

# Export to JSON
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta"' \
  --style json > logs/device_logs.json

# Search for specific text in messages
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta" AND eventMessage CONTAINS "Groq"'
```

## Log File Management

### File Naming Convention

- **Simulator logs:** `logs/sim-YYYYMMDD-HHMMSS.log`
- **Device print logs:** `logs/device-YYYYMMDD-HHMMSS.log`
- **Device structured logs:** `logs/device_YYYYMMDD_HHMMSS.txt`
- **Device log archives:** `logs/vivadicta_device_YYYYMMDD_HHMMSS.logarchive`

### Clean Up Old Logs

```bash
# List log files by age
ls -lht logs/

# Remove logs older than 7 days
find logs -name "*.log" -mtime +7 -delete
find logs -name "*.txt" -mtime +7 -delete

# Remove log archives (large files)
find logs -name "*.logarchive" -mtime +3 -delete
```

### View Recent Logs

```bash
# List 5 most recent log files
ls -lt logs/sim-*.log logs/device-*.log logs/device_*.txt 2>/dev/null | head -5

# View latest simulator log
cat "$(ls -t logs/sim-*.log 2>/dev/null | head -1)"

# View latest device log
cat "$(ls -t logs/device-*.log 2>/dev/null | head -1)"
```

## Troubleshooting

### Simulator Logs

**No simulator booted:**
- Launch simulator first: Xcode → Window → Devices and Simulators → Simulators → Boot
- Or via command: `xcrun simctl boot <UUID>`

**No logs appearing:**
- Ensure app is running and generating logs
- Check that VivaDicta is using `Logger` (not just `print()`)
- Verify subsystem in code: `Logger(subsystem: "com.antonnovoselov.VivaDicta", ...)`

**Log capture script fails:**
- Check script exists: `ls -la scripts/launch_simulator.sh`
- Make executable: `chmod +x scripts/launch_simulator.sh`
- Verify simulator UUID in script output

### Device Logs (Print-Based)

**Device not found:**
- Check connection: `xcrun xctrace list devices`
- Ensure device is trusted: System Settings → Privacy & Security → Developer Mode
- Verify device is unlocked

**No logs appearing:**
- Check `ENABLE_PRINT_LOGS` environment variable is set in script
- Verify LoggerExtension checks `ProcessInfo.processInfo.environment["ENABLE_PRINT_LOGS"]`
- Ensure print statements are not commented out

**App won't launch:**
- Try rebuilding and installing via Xcode first
- Check device UDID in script: `./scripts/launch_device.sh`
- Verify bundle ID: `com.antonnovoselov.VivaDicta`

### Device Logs (Structured)

**"Device not found" error:**
- Ensure device is connected: `xcrun xctrace list devices | grep iPhone`
- Verify UDID is correct: check `llmtemp/.device-log-udid`

**"Permission denied" with sudo:**
- Ensure you're using an admin account
- Try unlocking the device before running script
- Run script interactively (not in background)

**No logs in output:**
- Verify app was running during the time period
- Check subsystem name: `com.antonnovoselov.VivaDicta`
- Try opening `.logarchive` in Console.app to see all logs
- Ensure start timestamp was recorded: `cat llmtemp/.device-log-start-time`

**Script not created:**
- Check if `/stop-logs-device-structured` completed successfully
- Manually create script directory: `mkdir -p llmtemp`
- Review script template in command documentation

## Best Practices

1. **Choose the right logging method:**
   - **Simulator structured logging:** Best for most development workflows
   - **Device print logging:** When testing print statements or device-specific behavior
   - **Device structured logging:** For production debugging and comprehensive log collection

2. **Use descriptive log messages:**
   - Include emojis for visual scanning: 📱, 🎙️, 🎬, ✅, ❌, 📊
   - Add category information: `[RecordViewModel]`, `[AppState]`
   - Log state transitions clearly

3. **Always save logs to files:**
   - Logs are automatically timestamped
   - Keep logs directory organized: `logs/`
   - Add `logs/` to `.gitignore`

4. **Clean up old logs regularly:**
   - Remove logs older than 7 days
   - Delete large `.logarchive` files after analysis
   - Keep only relevant logs for bug tracking

5. **Combine with other debugging tools:**
   - Use `/screenshot` to capture visual state
   - Use AXe for UI automation during log capture
   - Use Xcode console for real-time debugging

6. **Structured logging over print statements:**
   - VivaDicta uses `Logger` - prefer structured logs
   - Only use print logging when absolutely necessary
   - Structured logs provide better metadata and filtering

7. **For production issues:**
   - Use device structured logging (`/start-logs-device-structured`)
   - Collect complete `.logarchive` files
   - Share with team or attach to bug reports

8. **Analyze logs systematically:**
   - Start with summary (error/warning counts)
   - Search by category or emoji
   - Follow specific workflows (recording → transcription → enhancement)
   - Use Console.app for advanced filtering of `.logarchive` files

## Additional Resources

- [Log Streaming Documentation (Apple)](https://developer.apple.com/documentation/os/logging)
- [Unified Logging and Activity Tracing (Apple)](https://developer.apple.com/wwdc/videos/)
- Console.app - Built-in macOS app for viewing `.logarchive` files
- `man log` - Manual page for log command
- VivaDicta LoggerExtension.swift - Conditional print logic implementation
