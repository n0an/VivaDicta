---
name: stop-logs-device
description: Stop the active device log capture session and report the log file location
disable-model-invocation: true
---

# stop-logs-device

## Task

Stop the currently running device log capture session and report the log file location.

## Instructions

1. **Stop the log capture process**:
   - Press `Ctrl+C` in the terminal where the log capture is running
   - This will terminate the `devicectl` process and stop capturing logs

2. **Find the most recent log file**:
   ```bash
   # Look for both properly timestamped files and the literal filename
   ls -t logs/device-*.log "logs/device-\$(date +%Y%m%d-%H%M%S).log" 2>/dev/null | head -1
   ```

3. **Display log file information**:
   ```bash
   LOGFILE=$(ls -t logs/device-*.log "logs/device-\$(date +%Y%m%d-%H%M%S).log" 2>/dev/null | head -1)
   if [ -n "$LOGFILE" ]; then
       echo "✅ Log capture stopped"
       echo ""
       echo "📝 Log file saved to: $LOGFILE"
       echo "📊 File size: $(du -h "$LOGFILE" | cut -f1)"
       echo "📅 Created: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOGFILE" 2>/dev/null || stat -c "%y" "$LOGFILE" 2>/dev/null | cut -d'.' -f1)"
       echo "📏 Lines: $(wc -l < "$LOGFILE" | tr -d ' ')"
       echo ""
       echo "💡 Quick actions:"
       echo "   View file:   cat \"$LOGFILE\""
       echo "   Tail file:   tail -f \"$LOGFILE\""
       echo "   Search:      grep 'pattern' \"$LOGFILE\""
   else
       echo "⚠️  No log files found in ./logs directory"
   fi
   ```

## Automated Script

For easier use, you can run this all-in-one command:

```bash
echo "⏹️  Stopping device log capture..."
echo ""
# Find most recent log file (handle both normal and literal filenames)
LOGFILE=$(ls -t logs/device-*.log "logs/device-\$(date +%Y%m%d-%H%M%S).log" 2>/dev/null | head -1)
if [ -n "$LOGFILE" ]; then
    echo "✅ Log capture stopped"
    echo ""
    echo "📝 Log file: $LOGFILE"
    echo "📊 Size: $(du -h "$LOGFILE" | cut -f1)"
    echo "📅 Created: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOGFILE" 2>/dev/null || stat -c "%y" "$LOGFILE" 2>/dev/null | cut -d'.' -f1)"
    echo "📏 Lines: $(wc -l < "$LOGFILE" | tr -d ' ')"
    echo ""
    echo "💡 Quick preview (last 10 lines):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    tail -10 "$LOGFILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "⚠️  No log files found in ./logs directory"
fi
```

## What This Does

1. **Stops the logging process** (you need to press Ctrl+C manually first)
2. **Finds the most recent log file** in the `./logs` directory
3. **Displays useful information**:
   - File path
   - File size
   - Creation timestamp
   - Number of lines
   - Last 10 lines preview

## Expected Output

```
⏹️  Stopping device log capture...

✅ Log capture stopped

📝 Log file: logs/device-20251016-213545.log
📊 Size: 245K
📅 Created: 2025-10-16 21:35:45
📏 Lines: 1247

💡 Quick preview (last 10 lines):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📱 Preload skipped: Current mode doesn't use WhisperKit (uses parakeet)
🎬 App became active - checking for stale Live Activity
✅ Parakeet ASR model loaded successfully
🦜 Starting Parakeet transcription with model: Parakeet 1.1B
📊 Audio duration: 3.45 seconds
✅ Parakeet transcription completed successfully
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Notes

- **Manual step required**: You must press `Ctrl+C` in the terminal running the log capture first
- **Multiple sessions**: If you have multiple log files, this shows the most recent one
- **Empty logs directory**: If no logs exist, you'll see a warning message
- **File preservation**: Log files are preserved until you manually delete them

## Background Process Management

If the log capture is running in a background process:

```bash
# Find the process
ps aux | grep "devicectl.*console"

# Kill by process ID
kill <PID>

# Or kill all devicectl processes (use with caution!)
pkill -f "devicectl.*console"
```

## Related

- `/start-logs-device` - Start device log capture
- `logs/device-*.log` - Timestamped log files
- `.gitignore` should include `logs/` to avoid committing large log files
