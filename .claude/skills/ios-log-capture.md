# iOS Log Capture

Use this skill when you need to capture console logs from iOS apps running in Simulator or on physical devices for debugging, testing, or monitoring purposes.

## Related Skills

- See [`xcodebuild-testing.md`](./xcodebuild-testing.md) for running tests that may require log analysis
- See [`axe-simulator-control.md`](./axe-simulator-control.md) for automating simulator interactions before capturing logs

## Additional Resources

- [XcodeBuildMCP Documentation](../../docs/Tools/XcodebuildMCPTools/XcodeBuildMCP_README.md) - Complete XcodeBuildMCP reference
- [XcodeBuildMCP Tools Reference](../../docs/Tools/XcodebuildMCPTools/XcodeBuildMCP_TOOLS.md) - All 61 tools organized by workflow
- [MCPLI Documentation](../../docs/Tools/MCPLI/MCPLI_README.md) - CLI tool for using MCP servers granularly
- [MCPLI Architecture](../../docs/Tools/MCPLI/MCPLI_architecture.md) - Detailed architecture and implementation guide

## Skill Flow

- Example queries:
  - "capture logs from the simulator"
  - "start logging the app in simulator"
  - "get console output from the running app"
  - "launch app and capture its logs"
  - "capture logs from physical iPhone"
- Notes:
  - Uses `mcpli` to access XcodeBuildMCP tools granularly
  - Requires Node.js 18+ and npm/npx
  - Log capture is session-based: start returns a session ID, stop returns the captured logs
  - Simulator must be booted before capturing logs
  - For VivaDicta project, bundle ID is typically `com.antonnovoselov.VivaDicta` (verify in Xcode)
  - Default simulator: iPhone 17 Pro, OS=26.0
  - **VivaDicta uses structured logging (os_log/Logger)** - no need to use `--captureConsole true` or relaunch the app

### 1. Determine Capture Target

**iOS Simulator** if:
- Testing in simulator environment
- Need quick iteration during development
- Want to capture logs from simulator app

→ Continue with **Path A: Simulator Log Capture** (steps 2A-5A)

**Physical Device** if:
- Testing on real hardware
- Need device-specific behavior
- Testing production builds

→ Continue with **Path B: Device Log Capture** (steps 2B-5B)

**Launch and Capture** if:
- Want to launch app and start log capture in one command
- Need to test app startup behavior
- Convenient workflow: launch → interact → stop capture

→ Continue with **Path C: Launch with Logs** (steps 2C-3C)

## Path A: Simulator Log Capture

### 2A. Get Simulator UUID

```bash
# List available simulators using AXe (simpler than mcpli)
axe list-simulators

# Example output:
# iPhone 17 Pro (26.0) - D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75 [Booted]
# iPhone 16 (25.0) - A12BC456-7DEF-89GH-IJKL-MNOPQRSTUVWX [Shutdown]

# Store the UUID for the target simulator
SIMULATOR_UUID="D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75"

# Or extract programmatically (get first booted simulator)
SIMULATOR_UUID=$(axe list-simulators | grep Booted | head -1 | sed -E 's/.*- ([A-F0-9-]+).*/\1/')
```

**Notes:**
- `axe list-simulators` shows status [Booted] or [Shutdown]
- Only booted simulators can capture logs
- Use `xcrun simctl list` for additional simulator details if needed
- UUID can also be obtained from Xcode's Devices and Simulators window

### 3A. Get Bundle ID

```bash
# Bundle ID is defined in your Xcode project
# Common locations to check:
# - Xcode: Target → General → Bundle Identifier
# - Info.plist: CFBundleIdentifier key

# For VivaDicta project, verify the bundle ID
# Example: com.antonnovoselov.VivaDicta
BUNDLE_ID="com.antonnovoselov.VivaDicta"
```

### 4A. Start Log Capture

```bash
# Start capturing logs (recommended for VivaDicta - no app relaunch needed)
mcpli start-sim-log-cap \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "$BUNDLE_ID" \
  -- npx -y xcodebuildmcp@latest

# Start capturing with console output (requires app relaunch - NOT needed for VivaDicta)
mcpli start-sim-log-cap \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "$BUNDLE_ID" \
  --captureConsole true \
  -- npx -y xcodebuildmcp@latest

# Save the returned session ID
# Example response:
# {
#   "logSessionId": "abc123-def456-ghi789"
# }
```

**Available parameters:**
- `--simulatorUuid` (required): UUID from list-sims
- `--bundleId` (required): App's bundle identifier
- `--captureConsole` (optional): Include console output (requires app relaunch)

**Important:**
- Response includes a `logSessionId` - save this for stopping the capture
- **For VivaDicta**: Omit `--captureConsole` flag - the app uses structured logging (os_log/Logger) and does NOT need to be relaunched
- If using `--captureConsole true`, the app will be relaunched (only needed for print() statements)
- Without `--captureConsole`, only structured logs are captured (sufficient for VivaDicta)

### 5A. Stop Log Capture

```bash
# Stop the log capture session and retrieve logs
LOG_SESSION_ID="abc123-def456-ghi789"

mcpli stop-sim-log-cap \
  --logSessionId "$LOG_SESSION_ID" \
  -- npx -y xcodebuildmcp@latest

# Save logs to file
mcpli stop-sim-log-cap \
  --logSessionId "$LOG_SESSION_ID" \
  -- npx -y xcodebuildmcp@latest > logs/simulator_logs.json

# Parse with jq for analysis
mcpli stop-sim-log-cap \
  --logSessionId "$LOG_SESSION_ID" \
  -- npx -y xcodebuildmcp@latest | jq '.logs'
```

**Notes:**
- Logs are returned as JSON in the response
- Use `jq` or other tools for parsing and filtering
- Create a `logs/` directory in your project for storing captured logs
- Consider timestamped filenames: `logs/sim_$(date +%Y%m%d_%H%M%S).json`

## Path B: Device Log Capture

### 2B. Get Device UDID

```bash
# List connected physical devices
# Note: XcodeBuildMCP should have a list-devices command
# If not available, use Xcode or system_profiler

# Via Xcode: Window → Devices and Simulators → Devices tab
# Via command line:
xcrun xctrace list devices

# Store the device UDID
DEVICE_ID="00008101-000123456789ABCD"
```

**Notes:**
- Device must be connected via USB or network
- Device must be trusted and paired with the Mac
- Ensure developer mode is enabled on the device (iOS 16+)

### 3B. Get Bundle ID

```bash
# Same as simulator - get from Xcode project
BUNDLE_ID="com.antonnovoselov.VivaDicta"
```

### 4B. Start Device Log Capture

```bash
# Start capturing logs from device
mcpli start-device-log-cap \
  --deviceId "$DEVICE_ID" \
  --bundleId "$BUNDLE_ID" \
  -- npx -y xcodebuildmcp@latest

# Save the returned session ID
# Example response:
# {
#   "logSessionId": "xyz789-abc123-def456"
# }
```

**Available parameters:**
- `--deviceId` (required): Device UDID from list-devices or xctrace
- `--bundleId` (required): App's bundle identifier

**Important:**
- Launches the app with console output capture enabled
- Response includes a `logSessionId` - save this for stopping the capture
- App will be launched on the device when capture starts

### 5B. Stop Device Log Capture

```bash
# Stop the device log capture session and retrieve logs
LOG_SESSION_ID="xyz789-abc123-def456"

mcpli stop-device-log-cap \
  --logSessionId "$LOG_SESSION_ID" \
  -- npx -y xcodebuildmcp@latest

# Save logs to file
mcpli stop-device-log-cap \
  --logSessionId "$LOG_SESSION_ID" \
  -- npx -y xcodebuildmcp@latest > logs/device_logs.json

# Parse with jq
mcpli stop-device-log-cap \
  --logSessionId "$LOG_SESSION_ID" \
  -- npx -y xcodebuildmcp@latest | jq '.logs'
```

## Path C: Launch with Logs

### 2C. Launch App and Start Log Capture

This is a convenience command that combines app launch with log capture in one step:

```bash
# Get simulator UUID first (using AXe)
SIMULATOR_UUID=$(axe list-simulators | grep Booted | head -1 | sed -E 's/.*- ([A-F0-9-]+).*/\1/')
BUNDLE_ID="com.antonnovoselov.VivaDicta"

# Launch app and start log capture (returns session ID)
SESSION=$(mcpli launch-app-logs-sim \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "$BUNDLE_ID" \
  -- npx -y xcodebuildmcp@latest 2>&1 | grep "session ID:" | sed -E 's/.*session ID: ([a-z0-9-]+).*/\1/')

echo "Log session started: $SESSION"

# Launch with app arguments
mcpli launch-app-logs-sim \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "$BUNDLE_ID" \
  --args '["--test-mode", "--verbose"]' \
  -- npx -y xcodebuildmcp@latest
```

**Available parameters:**
- `--simulatorUuid` (required): UUID from axe list-simulators
- `--bundleId` (required): App's bundle identifier
- `--args` (optional): JSON array of arguments to pass to the app

**Notes:**
- Launches the app and starts a log capture session
- Returns a session ID (like `start-sim-log-cap`)
- Useful for testing app startup behavior
- Logs are captured from app launch

### 3C. Stop Launch Log Capture

After interacting with the app, stop the capture and retrieve logs:

```bash
# Stop capture and get logs
mcpli stop-sim-log-cap \
  --logSessionId "$SESSION" \
  -- npx -y xcodebuildmcp@latest

# Save logs to file
mcpli stop-sim-log-cap \
  --logSessionId "$SESSION" \
  -- npx -y xcodebuildmcp@latest > logs/launch_logs.txt

# Parse and analyze
mcpli stop-sim-log-cap \
  --logSessionId "$SESSION" \
  -- npx -y xcodebuildmcp@latest | grep "Error\|Warning"
```

## Common Workflows

### Debug App Crash in Simulator

```bash
# 1. Get simulator UUID using AXe
SIMULATOR_UUID=$(axe list-simulators | grep Booted | head -1 | sed -E 's/.*- ([A-F0-9-]+).*/\1/')

# 2. Start log capture with console output
SESSION=$(mcpli start-sim-log-cap \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "com.antonnovoselov.VivaDicta" \
  --captureConsole true \
  -- npx -y xcodebuildmcp@latest | jq -r '.logSessionId')

# 3. Reproduce the crash (use AXe or manual interaction)
# ... perform actions that cause crash ...

# 4. Stop capture and save logs
mcpli stop-sim-log-cap \
  --logSessionId "$SESSION" \
  -- npx -y xcodebuildmcp@latest > logs/crash_$(date +%Y%m%d_%H%M%S).json

# 5. Analyze logs
jq '.logs[] | select(.level=="error")' logs/crash_*.json
```

### Capture Logs During Automated Testing

```bash
# 1. Start log capture (no app relaunch for VivaDicta)
SIMULATOR_UUID="D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75"
SESSION=$(mcpli start-sim-log-cap \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "com.antonnovoselov.VivaDicta" \
  -- npx -y xcodebuildmcp@latest | jq -r '.logSessionId')

# 2. Run automated tests with AXe or interact manually
axe tap -x 195 -y 400 --udid "$SIMULATOR_UUID"
axe gesture scroll-up --udid "$SIMULATOR_UUID"
axe type 'test input' --udid "$SIMULATOR_UUID"

# 3. Stop capture
mcpli stop-sim-log-cap \
  --logSessionId "$SESSION" \
  -- npx -y xcodebuildmcp@latest > logs/test_run.json
```

### Compare Device vs Simulator Logs

```bash
# 1. Capture simulator logs
SIM_SESSION=$(mcpli start-sim-log-cap \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "com.antonnovoselov.VivaDicta" \
  --captureConsole true \
  -- npx -y xcodebuildmcp@latest | jq -r '.logSessionId')

# ... perform test actions ...

mcpli stop-sim-log-cap \
  --logSessionId "$SIM_SESSION" \
  -- npx -y xcodebuildmcp@latest > logs/simulator.json

# 2. Capture device logs
DEV_SESSION=$(mcpli start-device-log-cap \
  --deviceId "$DEVICE_ID" \
  --bundleId "com.antonnovoselov.VivaDicta" \
  -- npx -y xcodebuildmcp@latest | jq -r '.logSessionId')

# ... perform same test actions on device ...

mcpli stop-device-log-cap \
  --logSessionId "$DEV_SESSION" \
  -- npx -y xcodebuildmcp@latest > logs/device.json

# 3. Compare logs
diff <(jq '.logs' logs/simulator.json) <(jq '.logs' logs/device.json)
```

### Quick Launch and Log Check

```bash
# Launch app, wait, then get logs
SIMULATOR_UUID=$(axe list-simulators | grep Booted | head -1 | sed -E 's/.*- ([A-F0-9-]+).*/\1/')

# Launch and capture session ID
SESSION=$(mcpli launch-app-logs-sim \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "com.antonnovoselov.VivaDicta" \
  -- npx -y xcodebuildmcp@latest 2>&1 | grep "session ID:" | sed -E 's/.*session ID: ([a-z0-9-]+).*/\1/')

# Wait for app to run (or interact with it)
sleep 5

# Get logs and filter for errors/warnings
mcpli stop-sim-log-cap \
  --logSessionId "$SESSION" \
  -- npx -y xcodebuildmcp@latest 2>&1 | grep -E "Error|Warning|error|warning"
```

## Troubleshooting

**"Simulator not found" error:**
- Ensure simulator is booted: `xcrun simctl list | grep Booted`
- Verify UUID is correct: `mcpli list-sims -- npx -y xcodebuildmcp@latest`
- Boot simulator: `xcrun simctl boot <UUID>` or use Xcode

**"Bundle identifier not found" error:**
- Verify bundle ID in Xcode: Target → General → Bundle Identifier
- Ensure app is installed in simulator/device
- Check for typos in bundle ID string

**"No logs captured" or empty logs:**
- For simulator: Use `--captureConsole true` to capture more verbose output
- Ensure app is actually running and producing logs
- Check if logs are being filtered by the system
- Verify app has logging statements (print, os_log, Logger)

**"Device not found" error:**
- Ensure device is connected and trusted
- Check device is visible: `xcrun xctrace list devices`
- Enable developer mode on iOS 16+ devices: Settings → Privacy & Security → Developer Mode
- Verify device is paired: Xcode → Window → Devices and Simulators

**mcpli command not found:**
- Install mcpli: `npm install -g mcpli`
- Or use npx: `npx mcpli@latest <command> -- npx -y xcodebuildmcp@latest`

**XcodeBuildMCP timeout or slow response:**
- First run may be slow as npx downloads the package
- Subsequent runs use cached package and are faster
- Increase timeout if needed: `mcpli --timeout 60000 <command> ...`

**JSON parsing errors:**
- Ensure output is valid JSON: `mcpli <command> ... | jq .`
- Check for stderr mixed with stdout - use `2>/dev/null` if needed
- Save raw output first, then parse: `... > output.json && jq . output.json`

## Best Practices

1. **Use session-based capture for long-running tests:**
   - Start capture, run tests, stop capture
   - Gives you full control over timing

2. **Use launch-app-logs-sim for quick checks:**
   - Single command for immediate feedback
   - Great for CI/CD pipelines

3. **Always save logs to files:**
   - Use timestamped filenames for tracking
   - Keep logs organized in a `logs/` directory
   - Add `logs/` to `.gitignore`

4. **Parse logs with jq:**
   - Filter by level: `jq '.logs[] | select(.level=="error")'`
   - Extract messages: `jq '.logs[].message'`
   - Count warnings: `jq '[.logs[] | select(.level=="warning")] | length'`

5. **Combine with other tools:**
   - Use AXe for UI automation during log capture
   - Use xcrun simctl for screenshots at error points
   - Use xcodebuild for running tests with log capture

6. **Clean up logs directory:**
   ```bash
   # Remove old logs (older than 7 days)
   find logs/ -name "*.json" -mtime +7 -delete
   ```

7. **Store bundle ID and UUIDs in environment variables:**
   ```bash
   export VIVADICTA_BUNDLE_ID="com.antonnovoselov.VivaDicta"
   export DEFAULT_SIM_UUID="D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75"
   ```

8. **Prefer structured logging over console capture:**
   - VivaDicta uses structured logging (os_log/Logger) - no need for `--captureConsole`
   - Structured logs are faster, cleaner, and don't require app relaunch
   - Only add `--captureConsole true` if you need print() output (requires app relaunch)
