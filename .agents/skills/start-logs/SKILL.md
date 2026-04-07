---
name: start-logs
description: Start a real-time log capture session for VivaDicta in the iOS Simulator
disable-model-invocation: true
---

# start-logs

## Task

Start a simulator log capture session for VivaDicta and keep it running in a long-lived shell session.

## Instructions

1. Ensure the logs directory exists:
   ```bash
   mkdir -p logs
   ```
2. Run the helper script in a long-lived shell session:
   ```bash
   ./scripts/launch_simulator.sh
   ```
3. Keep that session alive so `log stream` continues running until it is stopped.
4. Tell the user log capture is active and that they can now interact with the app.
5. Tell the user to use the `stop-logs` skill when they want the newest log file summarized or filtered.

## Notes

- The app is not relaunched. This attaches to the currently booted Simulator.
- The script writes to `logs/sim-YYYYMMDD-HHMMSS.log`.
- This captures structured `Logger` output, not raw `print()` statements.
- If no Simulator is booted, `./scripts/launch_simulator.sh` exits with an error.

## Related

- [`stop-logs`](../stop-logs/SKILL.md)
- [`ios-log-capture`](../ios-log-capture/SKILL.md)
