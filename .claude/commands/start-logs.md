# start-logs

## Task

Start a log capture session for VivaDicta app running in the iOS Simulator. This command does NOT relaunch the app - it captures structured logs from the already running app.

## Instructions

1. **Get the simulator UUID** using AXe:
   ```bash
   axe list-simulators | grep Booted | head -1
   ```
   Extract the UUID from the output.

2. **Ensure llmtemp directory exists**:
   ```bash
   mkdir -p llmtemp
   ```

3. **Start the log capture session** using mcpli:
   ```bash
   mcpli start-sim-log-cap \
     --simulatorUuid "<UUID>" \
     --bundleId "com.antonnovoselov.VivaDicta" \
     -- npx -y xcodebuildmcp@latest
   ```

4. **Extract and save the session ID** from the JSON response:
   - Look for the `logSessionId` field in the response
   - Save it to `llmtemp/.log-session-id` file for automatic retrieval by `/stop-logs`
   - Display it clearly to the user as well

5. **Report to the user**:
   - Confirm that log capture session has started
   - Display the session ID prominently
   - Remind the user: "Log capture is active. Interact with your app, then use `/stop-logs` to retrieve the logs (session ID will be used automatically)"
   - Note: The app continues running and does NOT need to be relaunched
   - Mention that they can also use `/stop-logs <session-id>` to explicitly specify a different session

## Important Notes

- **VivaDicta uses structured logging (os_log/Logger)** - no `--captureConsole` flag needed
- The app will NOT be relaunched - it keeps running with its current state
- The user can interact with the app manually while logs are being captured
- The session ID is required to stop the capture later

## Technical Details

- Uses the `ios-log-capture.md` skill (Path A: Simulator Log Capture)
- Log capture is session-based: start returns a session ID, stop retrieves logs
- Only structured logs are captured (sufficient for VivaDicta)
- Requires mcpli and Node.js 18+

## Additional Resources

- [iOS Log Capture Skill](../.claude/skills/ios-log-capture.md) - Complete log capture reference
- [MCPLI Documentation](../docs/Tools/MCPLI/MCPLI_README.md) - CLI wrapper documentation
- [XcodeBuildMCP Tools](../docs/Tools/XcodebuildMCPTools/XcodeBuildMCP_TOOLS.md) - All available tools
