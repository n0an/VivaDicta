---
name: stop-logs-device-structured
description: Collect structured device logs since the timestamp recorded by start-logs-device-structured using sudo log collect
disable-model-invocation: true
---

# stop-logs-device-structured

You are given the following context:
$ARGUMENTS

## Task

Finish the structured device log workflow after `start-logs-device-structured`, guide the user through running the collection script, then summarize or filter the newest exported text log.

## Instructions

1. Verify the prerequisites exist:
   - `llmtemp/.device-log-start-time`
   - `llmtemp/.device-log-udid`
   - `./scripts/collect_device_logs.sh`
2. Ensure the collection script is executable:
   ```bash
   chmod +x ./scripts/collect_device_logs.sh
   ```
3. Tell the user to run the script in their terminal because it requires interactive sudo access:
   ```bash
   ./scripts/collect_device_logs.sh
   ```
4. Wait for the user to confirm the script finished.
5. After it finishes, find the newest exported text log:
   ```bash
   ls -t logs/device_*.txt 2>/dev/null | head -1
   ```
6. Analyze the file based on `$ARGUMENTS`:
   - if empty: show errors, warnings, and a short tail
   - if `all`: show the full file
   - otherwise: treat the argument as a search term and show matching lines

## Notes

- The script also creates `logs/vivadicta_device_*.logarchive` for later use in Console.app.
- If the prerequisite timestamp or UDID files are missing, tell the user to run `start-logs-device-structured` first.
- If the script has not been run yet, do not pretend the logs are available.

## Helpful Commands

```bash
LOGFILE=$(ls -t logs/device_*.txt 2>/dev/null | head -1)

grep -i "error\\|warning" "$LOGFILE"
tail -20 "$LOGFILE"
log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta"'
```

## Related

- [`start-logs-device-structured`](../start-logs-device-structured/SKILL.md)
- [`ios-log-capture`](../ios-log-capture/SKILL.md)
