---
name: stop-logs-device-structured
description: Collect structured device logs since the timestamp recorded by start-logs-device-structured using sudo log collect
disable-model-invocation: true
---

# stop-logs-device-structured

You are given the following context:
ARGUMENTS: {{ARGS}}

## Task

Collect device logs from the timestamp recorded by `/start-logs-device-structured` and analyze them. This uses `sudo log collect` which requires your password.

## Instructions

1. **Check if collection script exists, create if needed**:
   - If `scripts/collect_device_logs.sh` doesn't exist, create it with the proper script (see script template below)
   - Make it executable: `chmod +x scripts/collect_device_logs.sh`

2. **Tell the user to run the script**:
   - Inform them: "I've prepared the log collection script. Please run it in your terminal (it needs interactive sudo access):"
   - Show them: `./scripts/collect_device_logs.sh`
   - Tell them: "The script will prompt for your sudo password, collect the logs, and show a summary."

3. **Wait for user confirmation**:
   - Ask them to let you know when it's done
   - Once done, proceed to analyze the logs

4. **After script completes, analyze the logs**:
   - Find the latest log file: `logs/device_*.txt`
   - Read and analyze based on ARGS:
     - Default: Show errors and warnings
     - If ARGS specifies, filter accordingly (e.g., "show all logs", "filter for 'keyboard'")
   - Provide detailed analysis as requested

## Script Template

The `llmtemp/collect_device_logs.sh` script should contain:

```bash
#!/bin/bash

# Device log collection script
# This script requires sudo access and will prompt for your password

# Read timestamp and UDID from temp files
if [ ! -f "llmtemp/.device-log-start-time" ] || [ ! -f "llmtemp/.device-log-udid" ]; then
  echo "Error: Start timestamp or UDID not found."
  echo "Please run /start-logs-device-structured first."
  exit 1
fi

START_TIME=$(cat llmtemp/.device-log-start-time)
UDID=$(cat llmtemp/.device-log-udid)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGARCHIVE="logs/vivadicta_device_${TIMESTAMP}.logarchive"
LOGFILE="logs/device_${TIMESTAMP}.txt"

echo "Collecting device logs from device"
echo "Start time: ${START_TIME}"
echo "UDID: ${UDID}"
echo ""
echo "This will prompt for your sudo password..."
echo ""

# Collect logs from device
sudo log collect \
  --device-udid "${UDID}" \
  --start "${START_TIME}" \
  --output "${LOGARCHIVE}"

if [ $? -eq 0 ]; then
  echo ""
  echo "✓ Log archive collected: ${LOGARCHIVE}"
  echo ""
  echo "Extracting VivaDicta logs..."

  # Extract and filter logs
  log show "${LOGARCHIVE}" \
    --predicate 'subsystem == "com.antonnovoselov.VivaDicta"' \
    --style compact > "${LOGFILE}"

  echo "✓ Filtered logs saved: ${LOGFILE}"
  echo ""

  # Show summary
  TOTAL_LINES=$(wc -l < "${LOGFILE}")
  ERRORS=$(grep -ic "error" "${LOGFILE}" || echo "0")
  WARNINGS=$(grep -ic "warning" "${LOGFILE}" || echo "0")

  echo "Summary:"
  echo "  Total log entries: ${TOTAL_LINES}"
  echo "  Errors: ${ERRORS}"
  echo "  Warnings: ${WARNINGS}"
  echo ""

  if [ ${ERRORS} -gt 0 ] || [ ${WARNINGS} -gt 0 ]; then
    echo "Recent errors/warnings:"
    grep -iE "error|warning" "${LOGFILE}" | tail -20
  fi

  # Clean up temp files
  rm -f llmtemp/.device-log-start-time
  rm -f llmtemp/.device-log-udid

  echo ""
  echo "✓ Log collection complete!"
  echo ""
  echo "To analyze further:"
  echo "  • View text logs: cat ${LOGFILE}"
  echo "  • Open in Console.app: open ${LOGARCHIVE}"
else
  echo "✗ Log collection failed"
  exit 1
fi
```

## Example Usage

```bash
# Collect logs since start (prompts for sudo password)
/stop-logs-device-structured

# Collect with custom analysis
/stop-logs-device-structured show all logs
/stop-logs-device-structured show logs related to keyboard
/stop-logs-device-structured analyze recording errors
```

## Important Notes

- **Requires sudo password** - you'll be prompted to enter your macOS password
- Log collection may take 30-60 seconds depending on log volume
- Creates a `.logarchive` file (can be opened in Console.app)
- Also creates a filtered `.txt` file for easy reading
- The `.logarchive` preserves all metadata and can be re-analyzed later

## Advanced Analysis

After collection, you can re-analyze the `.logarchive`:

```bash
# View all VivaDicta logs
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta"'

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

# Open in Console.app for GUI analysis
open logs/vivadicta_device_*.logarchive
```

## Technical Details

- Uses native `log collect` command (most reliable method)
- Creates a complete log archive from the device
- Filters by subsystem for VivaDicta-specific logs
- Supports rich predicates for advanced filtering
- `.logarchive` files can be shared for debugging

## Troubleshooting

**"Device not found" error:**
- Ensure device is connected and trusted
- Check UDID: `xcrun xctrace list devices`

**"Permission denied" even with sudo:**
- Ensure you're using an admin account
- Try unlocking the device

**No logs in output:**
- Check if app was running during the time period
- Verify subsystem name: `com.antonnovoselov.VivaDicta`
- Try opening the `.logarchive` in Console.app to see all logs

## Additional Resources

- [iOS Log Capture Skill](../ios-log-capture/SKILL.md) - Complete log capture reference
- Apple Developer: `man log` - log command documentation
- Console.app - GUI for viewing `.logarchive` files
