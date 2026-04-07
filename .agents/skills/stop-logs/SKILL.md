---
name: stop-logs
description: Stop the active simulator log capture session and display a summary of captured logs
disable-model-invocation: true
---

# stop-logs

You are given the following context:
$ARGUMENTS

## Task

Stop the active simulator log-capture session and summarize the newest simulator log file. Optionally filter the output based on the provided arguments.

## Instructions

1. Stop the active `log stream` session. If the capture is running in an interactive shell session, send `Ctrl+C` to that session or otherwise terminate the active process.
2. Find the newest simulator log file:
   ```bash
   ls -t logs/sim-*.log 2>/dev/null | head -1
   ```
3. Summarize the file:
   - path
   - size
   - modified time
   - line count
   - number of error/fault lines
   - number of warning lines
4. Analyze the file based on `$ARGUMENTS`:
   - if empty: show the last 20 lines
   - if `errors`: show matching error or fault lines
   - if `warnings`: show warning lines
   - if `all`: show the whole file
   - otherwise: treat the argument as a search term and show matching lines

## Helpful Commands

```bash
LOGFILE=$(ls -t logs/sim-*.log 2>/dev/null | head -1)

du -h "$LOGFILE"
wc -l "$LOGFILE"
grep -i "error\\|fault" "$LOGFILE"
grep -i "warning" "$LOGFILE"
tail -20 "$LOGFILE"
```

## Notes

- If no simulator log file exists, report that clearly instead of guessing.
- Preserve the log file; this skill summarizes it, it does not delete it.
- The expected companion workflow is `start-logs` followed by `stop-logs`.

## Related

- [`start-logs`](../start-logs/SKILL.md)
- [`ios-log-capture`](../ios-log-capture/SKILL.md)
