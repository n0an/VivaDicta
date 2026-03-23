---
name: stop-logs
description: Stop the active simulator log capture session and display a summary of captured logs
disable-model-invocation: true
---

# stop-logs

You are given the following context:
ARGUMENTS: {{ARGS}}

## Task

Stop the active simulator log capture session and display a summary of the captured logs. Optionally analyze the logs based on user instructions.

## Instructions

1. **Stop the log capture process**:
   - Press `Ctrl+C` in the terminal where the log capture is running
   - This will terminate the `log stream` process and stop capturing logs

2. **Find the most recent log file**:
   ```bash
   ls -t logs/sim-*.log 2>/dev/null | head -1
   ```

3. **Display log file information**:
   ```bash
   LOGFILE=$(ls -t logs/sim-*.log 2>/dev/null | head -1)
   if [ -n "$LOGFILE" ]; then
       echo "✅ Log capture stopped"
       echo ""
       echo "📝 Log file: $LOGFILE"
       echo "📊 Size: $(du -h "$LOGFILE" | cut -f1)"
       echo "📅 Created: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOGFILE" 2>/dev/null || stat -c "%y" "$LOGFILE" 2>/dev/null | cut -d'.' -f1)"
       echo "📏 Lines: $(wc -l < "$LOGFILE" | tr -d ' ')"
       echo ""

       # Analyze logs
       ERRORS=$(grep -i "error\|fault" "$LOGFILE" | wc -l | tr -d ' ')
       WARNINGS=$(grep -i "warning" "$LOGFILE" | wc -l | tr -d ' ')

       echo "📊 Summary:"
       echo "   Errors: $ERRORS"
       echo "   Warnings: $WARNINGS"
       echo ""
   else
       echo "⚠️  No log files found in ./logs directory"
   fi
   ```

4. **Analyze logs based on ARGS** (if provided):
   - If ARGS is empty: show last 20 lines
   - If ARGS contains "errors": show all error lines
   - If ARGS contains "warnings": show all warning lines
   - If ARGS contains search term: grep for that term
   - If ARGS contains "all": show entire file

## Automated Script

For easier use, run this all-in-one command:

```bash
echo "⏹️  Stopping simulator log capture..."
echo ""
LOGFILE=$(ls -t logs/sim-*.log 2>/dev/null | head -1)
if [ -n "$LOGFILE" ]; then
    echo "✅ Log capture stopped"
    echo ""
    echo "📝 Log file: $LOGFILE"
    echo "📊 Size: $(du -h "$LOGFILE" | cut -f1)"
    echo "📅 Created: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOGFILE" 2>/dev/null || stat -c "%y" "$LOGFILE" 2>/dev/null | cut -d'.' -f1)"
    echo "📏 Lines: $(wc -l < "$LOGFILE" | tr -d ' ')"
    echo ""

    # Count errors and warnings
    ERRORS=$(grep -i "error\|fault" "$LOGFILE" | wc -l | tr -d ' ')
    WARNINGS=$(grep -i "warning" "$LOGFILE" | wc -l | tr -d ' ')

    echo "📊 Summary:"
    echo "   Errors: $ERRORS"
    echo "   Warnings: $WARNINGS"
    echo ""

    echo "💡 Last 20 lines:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    tail -20 "$LOGFILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "⚠️  No log files found in ./logs directory"
fi
```

## Example Usage

```bash
# Stop and show summary with last 20 lines
/stop-logs

# Stop and show all errors
/stop-logs errors

# Stop and show all warnings
/stop-logs warnings

# Stop and search for specific term
/stop-logs keyboard
/stop-logs Parakeet

# Stop and show entire file
/stop-logs all
```

## Expected Output

```
⏹️  Stopping simulator log capture...

✅ Log capture stopped

📝 Log file: logs/sim-20251016-213545.log
📊 Size: 142K
📅 Created: 2025-10-16 21:35:45
📏 Lines: 856

📊 Summary:
   Errors: 0
   Warnings: 2

💡 Last 20 lines:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2025-10-16 21:35:17.123456-0700 VivaDicta: [AppState] 📱 Preload skipped
2025-10-16 21:35:17.234567-0700 VivaDicta: [AppState] 🎬 App became active
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Log Analysis Commands

```bash
# View entire log file
cat logs/sim-20251016-213545.log

# Search for specific emoji
grep "📱" logs/sim-*.log

# Show only error lines
grep -i "error\|fault" logs/sim-*.log

# Show only warning lines
grep -i "warning" logs/sim-*.log

# Search for specific category
grep "\[AudioPrewarmManager\]" logs/sim-*.log

# Count total log entries
wc -l logs/sim-*.log

# View last 50 lines
tail -50 logs/sim-*.log
```

## Important Notes

- **Manual step required**: You must press `Ctrl+C` to stop the log stream first
- **Multiple sessions**: If you have multiple log files, this shows the most recent one
- **File preservation**: Log files are preserved until you manually delete them
- **Emojis preserved**: All emojis and special characters are maintained in the log file

## Background Process Management

If the log capture is running in a background process:

```bash
# Find the process
ps aux | grep "log stream"

# Kill by process ID
kill <PID>

# Or kill all log stream processes
pkill -f "log stream.*VivaDicta"
```

## Related

- `/start-logs` - Start simulator log capture
- `logs/sim-*.log` - Timestamped simulator log files
- `.gitignore` should include `logs/` to avoid committing large log files
