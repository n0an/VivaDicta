# stop-logs

You are given the following context:
ARGUMENTS: {{ARGS}}

## Task

Stop an active log capture session and retrieve the captured logs. Optionally analyze the logs based on user instructions.

## Instructions

1. **Get the session ID**:
   - Check if ARGS contains a session ID
   - If ARGS contains a session ID, use it
   - If ARGS is empty or only contains analysis instructions:
     - Try to read session ID from `llmtemp/.log-session-id`
     - If file exists, use that session ID
     - If file doesn't exist, inform the user they need to run `/start-logs` first or provide a session ID
   - Session ID format: typically looks like `abc123-def456-ghi789`

2. **Ensure logs directory exists**:
   ```bash
   mkdir -p logs
   ```

3. **Stop the log capture session** and save logs to a timestamped file:
   ```bash
   mcpli stop-sim-log-cap \
     --logSessionId "<session-id>" \
     -- npx -y xcodebuildmcp@latest > logs/sim_$(date +%Y%m%d_%H%M%S).json
   ```

4. **Parse and analyze the logs**:
   - Read the saved JSON file
   - By default, look for errors and warnings:
     ```bash
     jq '.logs[] | select(.level=="error" or .level=="warning")' logs/sim_*.json | tail -20
     ```
   - If ARGS contains specific instructions (e.g., "show all logs", "filter for 'keyboard'"), follow those instructions

5. **Report results**:
   - Confirm that log capture session has been stopped
   - Display the saved log file path
   - Show a summary:
     - Total number of log entries
     - Number of errors (if any)
     - Number of warnings (if any)
   - Display the most relevant logs based on ARGS or show errors/warnings by default
   - If requested in ARGS, provide detailed analysis

## Example Usage

```bash
# Stop the most recent session (uses saved session ID automatically)
/stop-logs

# Stop with custom analysis
/stop-logs show all logs
/stop-logs show logs related to keyboard
/stop-logs analyze app startup logs

# Stop specific session explicitly
/stop-logs abc123-def456-ghi789

# Stop specific session with custom analysis
/stop-logs abc123-def456-ghi789 show logs related to keyboard
```

## Important Notes

- **Session ID is optional** - if not provided, uses the session ID from the most recent `/start-logs`
- Session ID can be explicitly provided to stop a specific session
- Logs are saved to `logs/` directory (gitignored)
- JSON format allows easy parsing with `jq`
- Timestamped filenames prevent overwrites
- The saved session ID file is `llmtemp/.log-session-id`

## Common jq Queries for Analysis

```bash
# Filter errors only
jq '.logs[] | select(.level=="error")' logs/file.json

# Extract messages
jq '.logs[].message' logs/file.json

# Count warnings
jq '[.logs[] | select(.level=="warning")] | length' logs/file.json

# Filter by content
jq '.logs[] | select(.message | contains("keyboard"))' logs/file.json

# Show recent entries (last 10)
jq '.logs[-10:]' logs/file.json
```

## Technical Details

- Uses the `ios-log-capture.md` skill (Step 5A: Stop Log Capture)
- Logs are returned as JSON from the session
- Use `jq` for powerful log analysis and filtering
- Saved logs can be analyzed later if needed

## Additional Resources

- [iOS Log Capture Skill](../.claude/skills/ios-log-capture.md) - Complete log capture reference
- [MCPLI Documentation](../docs/Tools/MCPLI/MCPLI_README.md) - CLI wrapper documentation
- [XcodeBuildMCP Tools](../docs/Tools/XcodebuildMCPTools/XcodeBuildMCP_TOOLS.md) - All available tools
