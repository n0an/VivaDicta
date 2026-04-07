---
name: simulator-screenshot-time
description: Set the iOS Simulator status bar to screenshot-ready state with clean time, battery, and signal
disable-model-invocation: true
---

# Simulator Screenshot Time

You are given the following context:
$ARGUMENTS

## Instructions

Set the iOS Simulator status bar to screenshot-ready state with time 9:41, full battery, and full signal bars.

Run this command to set the status bar:

```bash
xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100 --cellularBars 4
```

If the user wants to reset back to real time, run:

```bash
xcrun simctl status_bar booted clear
```

If arguments are provided, interpret them as follows:
- "reset" or "clear" - clear the status bar override
- A specific time like "10:30" - use that time instead of 9:41
- "wifi" - also set WiFi bars to full with `--wifiBars 3`
