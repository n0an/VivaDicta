# start-logs-device

## Task

Launch VivaDicta on a connected physical device with print logging enabled and keep the console capture running in a long-lived shell session.

## Instructions

1. Verify the setup before committing to a capture session:
   ```bash
   ./scripts/launch_device.sh --check
   ```
   This resolves the device and bundle id and prints both without launching anything. If it reports an error, fix that first — the message says what is wrong.
2. Ensure the logs directory exists:
   ```bash
   mkdir -p logs
   ```
3. Run the helper script in a long-lived shell session:
   ```bash
   ./scripts/launch_device.sh
   ```
4. Keep that session alive while the user reproduces the issue on device.
5. Tell the user which log file the script reported (`logs/device-YYYYMMDD-HHMMSS.log`).
6. Tell the user to use the `stop-logs-device` skill when they want the newest file summarized.

## Options

| Flag | Effect |
| --- | --- |
| `--check` | Preflight only: resolve device + bundle id, print them, exit without launching. |
| `--device <udid>` | Target a specific device instead of auto-discovering one. |
| `--bundle <id>` | Target a specific bundle id instead of auto-resolving one. |

## How resolution works

- **Device**: auto-discovered from `xcrun devicectl list devices` — the entry that is real hardware (`reality == physical`), runs iOS, and has `tunnelState == connected`. Simulators appear in the same list and are excluded. Zero matches or several both fail with a readable message listing what was found.
- **Bundle id**: `com.antonnovoselov.VivaDicta`, if it is actually installed. Both the QA and Release configurations build under that id, so it covers a QA build run from Xcode as well as a TestFlight or App Store install. The Debug configuration uses `com.antonnovoselov.VivaDicta-beta`, but that build is not in use; pass `--bundle` to target it if it is ever installed.

## Notes

- The script uses `xcrun devicectl device process launch --console`.
- `ENABLE_PRINT_LOGS=1` is set so mirrored print output is visible in the console stream.
- `--terminate-existing` kills any running instance before launching, so the app restarts and in-progress state is lost.
- Works only where `devicectl` can reach the device: plugged in (or on the same network), unlocked, and paired.

## Known limitation: no timestamps

`--console` streams the process's **stdout**, which is where `print` goes. Unified-log metadata does not appear there, so these lines carry no timestamp, level, category, or thread — unlike the simulator capture (`start-logs`), whose lines have all four.

This is an Apple limitation, not a script one: `log stream` has no `--device` flag, so there is no live structured stream from a phone. Only `log collect` accepts `--device-udid`, and that is the batch path.

The two ways around it:

- Have `LoggerExtension`'s print mirror stamp each line itself (app-side change; only affects builds you install).
- Use `start-logs-device-structured`, which captures the real unified log with timestamps, levels and categories — and is the only tier that reaches app extensions. Costs interactive `sudo` and a ~250 MB archive.

## Gotcha

`xcrun devicectl device info apps` omits App Store and TestFlight installs unless you pass `--include-all-apps`. Without that flag an installed app looks missing, which makes a "not installed" error very confusing to diagnose.

## Related

- [`stop-logs-device`](../stop-logs-device/SKILL.md)
- [`start-logs-device-structured`](../start-logs-device-structured/SKILL.md)
- [`ios-log-capture`](../ios-log-capture/SKILL.md)
