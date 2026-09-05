---
name: logs-start
description: Start a VivaDicta log capture. Defaults to the simulator; takes sim, device, or structured to pick a tier.
disable-model-invocation: true
---

# logs-start

Start a log capture. Stop it with [`logs-stop`](../logs-stop/SKILL.md), which
resolves the active tier on its own - you never have to name it again.

## Argument

`$ARGUMENTS` selects the tier. Empty means `sim`.

| Argument | Tier | Reaches extensions? | Cost |
| --- | --- | --- | --- |
| *(empty)* or `sim` | Simulator, live unified log | yes (all sim processes) | none |
| `device` | Device, live stdout | **no, main app only** | none |
| `structured` | Device, unified log archive | yes | interactive `sudo`, large archive |

Anything else: say what was passed, list the three, and stop. Do not guess.

**When invoked with no argument**, start the simulator capture as usual, then
close your report with this reminder so the other tiers stay discoverable:

> Started the simulator capture (default). Other tiers: `/logs-start device`
> for live device stdout (main app only), `/logs-start structured` for the
> device unified log (the only tier that sees the keyboard and other
> extensions).

Do not ask which tier to use instead of starting - the default is the default.
Only mention the alternatives after the capture is already running.

## Choosing a tier

- **`sim`** is the default because it is free and the richest: real unified-log
  metadata, timestamps, levels, categories, threads.
- **`device`** is for hardware-only bugs. Live and cheap, but see the limitation
  below - it cannot see the keyboard or any other extension.
- **`structured`** is the only tier that sees extensions on hardware. Reach for
  it when the keyboard, share, action, or widget target is involved, or for a
  post-mortem `.logarchive` you want to reopen in Console.app.

## sim

1. `mkdir -p logs`
2. Run `./scripts/launch_simulator.sh` in a **background/long-lived** shell so
   `log stream` keeps running.
3. Report the `logs/sim-YYYYMMDD-HHMMSS.log` path the script prints.

Attaches to the already-booted Simulator; it does not relaunch the app, and it
fails if none is booted. Captures `Logger` output filtered to
`subsystem == "com.antonnovoselov.VivaDicta"`; raw `print()` is not included.

## device

1. `./scripts/launch_device.sh --check` first - it resolves device and bundle id
   without launching. Fix whatever it reports before continuing.
2. `mkdir -p logs`
3. Run `./scripts/launch_device.sh` in a **background/long-lived** shell.
4. Report the `logs/device-YYYYMMDD-HHMMSS.log` path.

Uses `xcrun devicectl device process launch --console` with
`ENABLE_PRINT_LOGS=1`. `--terminate-existing` restarts the app, so in-progress
state is lost.

### Limitation: main app only, no extensions

`--console` pipes the stdout of the **single process devicectl launched**. Every
extension runs in its own system-spawned process, so devicectl never sees it.
Their output is absent entirely and nothing says so - you get a
complete-looking stream that is silently missing a target.

Measured: a capture during keyboard use carried 213 lines from `VivaDicta/` and
0 from `VivaDictaKeyboard/`, though the keyboard logs from
`KeyboardViewController`, `KeyboardTextProcessor` and `VivaModeManager`. Use
`structured` for extensions.

### Timestamps

Lines carry time, level and call site, because `LoggerExtension`'s print mirror
stamps them itself:

```
19:09:40.709 [INFO] VivaDicta/AIService.swift:666 Loaded 1 Viva Modes
```

That is app-side, so it only appears in builds you install. **Bare, unstamped
lines mean the installed binary predates the print mirror - rebuild to the
device rather than changing the capture.** Category and thread are still absent;
stdout has no room for unified-log metadata.

## structured

Starts nothing - it only records where to collect *from*. `logs-stop` does the
work.

1. Find the device:
   ```bash
   xcrun xctrace list devices | grep iPhone | grep -v Simulator | head -1
   ```
2. `mkdir -p llmtemp`
3. ```bash
   date '+%Y-%m-%d %H:%M:%S' > llmtemp/.device-log-start-time
   echo "<UDID>" > llmtemp/.device-log-udid
   ```
4. Report the start time and UDID, and warn that `logs-stop` will need
   interactive `sudo` and will write a large archive.

Why this tier reaches extensions: `sudo log collect --device-udid` pulls the
device's whole unified log, and extension lines survive the subsystem filter
because `LoggerExtension.swift` hardcodes one subsystem across all targets:

```swift
private nonisolated let kLoggingSubsystem = "com.antonnovoselov.VivaDicta"
```

That constant is load-bearing. If a target is ever changed to log under its own
bundle id, it disappears from these captures silently.

## Concurrent captures

`sim` and `device` can run at once; `logs-stop` handles all active tiers. Do not
start a second capture of the *same* tier - the first one's file stops receiving
the lines you expect.

## Manual analysis

```bash
ls -lt logs/sim-*.log | head -5
grep -i "error\|fault" logs/sim-*.log
grep "\[AppState\]" logs/sim-*.log

log show logs/vivadicta_device_*.logarchive \
  --predicate 'subsystem == "com.antonnovoselov.VivaDicta"'
```

## Related

- [`logs-stop`](../logs-stop/SKILL.md)
- [`xcodebuild-testing`](../xcodebuild-testing/SKILL.md)
- [`axe-simulator-control`](../axe-simulator-control/SKILL.md) - drive the simulator before capturing
