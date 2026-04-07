---
name: stop-logs-device
description: Stop the active device log capture session and report the log file location
disable-model-invocation: true
---

# stop-logs-device

## Task

Stop the active device print-log capture session and summarize the newest device log file.

## Instructions

1. Stop the active `devicectl` console session. If it is running in an interactive shell session, send `Ctrl+C` to that session or otherwise terminate the active process.
2. Find the newest device print log:
   ```bash
   ls -t logs/device-*.log 2>/dev/null | head -1
   ```
3. Summarize the file:
   - path
   - size
   - modified time
   - line count
   - short tail preview

## Helpful Commands

```bash
LOGFILE=$(ls -t logs/device-*.log 2>/dev/null | head -1)

du -h "$LOGFILE"
wc -l "$LOGFILE"
tail -10 "$LOGFILE"
grep -i "error" "$LOGFILE"
```

## Notes

- If no matching file exists, report that clearly.
- The expected companion workflow is `start-logs-device` followed by `stop-logs-device`.
- This skill does not delete logs; it only stops the live stream and summarizes the latest file.

## Related

- [`start-logs-device`](../start-logs-device/SKILL.md)
- [`ios-log-capture`](../ios-log-capture/SKILL.md)
