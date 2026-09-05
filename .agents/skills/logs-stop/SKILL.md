---
name: logs-stop
description: Stop whichever VivaDicta log capture is active, then summarize it. Detects the tier itself; takes an optional filter.
disable-model-invocation: true
---

# logs-stop

Stop the active capture(s) started by [`logs-start`](../logs-start/SKILL.md) and
summarize the result. **Never ask the user which tier is running - detect it.**

## Step 1: detect

Run all three checks. More than one tier can be active.

```bash
pgrep -f "simctl spawn.*log stream" >/dev/null && echo "sim ACTIVE"
pgrep -f "devicectl device process launch" >/dev/null && echo "device ACTIVE"
[ -f llmtemp/.device-log-start-time ] && echo "structured PENDING: $(cat llmtemp/.device-log-start-time)"
```

`structured` has no process - a marker file is the only evidence. If nothing is
found, say so plainly and stop; do not summarize a stale file as if it were
fresh.

## Step 2: stop and summarize each active tier

### sim

```bash
pkill -f "simctl spawn.*log stream"
LOGFILE=$(ls -t logs/sim-*.log 2>/dev/null | head -1)
```

### device

```bash
pkill -f "devicectl device process launch"
LOGFILE=$(ls -t logs/device-*.log 2>/dev/null | head -1)
```

The capture ends with `App terminated due to signal 15` - that is this skill's
`pkill`, not a crash. Say so rather than reporting it as a failure.

### structured

**Check staleness first.** If `llmtemp/.device-log-start-time` is more than a few
hours old, show its timestamp and ask before collecting - the marker may be
left over from an abandoned session, and collecting is expensive.

The script needs interactive `sudo`, so the user must run it themselves. **Root
is a hard requirement inside `/usr/bin/log`, not a choice this script makes** -
verified 2026-09-05, running it unprivileged fails outright and writes nothing:

```
$ /usr/bin/log collect --device-udid <udid> --start <time> --output out.logarchive
log: Must be root to collect logs from attached device
```

There is no flag or output-path that avoids it, so do not try to drop the sudo.
(Local-only `log collect`, with no `--device-udid`, is the case that can run
unprivileged - the device path talks to attached hardware.)

Note also that `log` is a shell builtin in Anton's zsh, so a bare `log show ...`
typed interactively fails with `too many arguments`. Use `/usr/bin/log`. The
script is unaffected: it runs under `#!/bin/bash`.



```bash
chmod +x ./scripts/collect_device_logs.sh
./scripts/collect_device_logs.sh
```

Ask them to run it, wait for confirmation, then read the newest export:

```bash
LOGFILE=$(ls -t logs/device_*.txt 2>/dev/null | head -1)
```

It also writes `logs/vivadicta_device_*.logarchive`, reopenable in Console.app.
Do not claim the logs exist before the user confirms the script finished. Remove
the marker files once collection succeeds so the next `logs-stop` does not
re-trigger it.

## Step 3: report

Per file: path, size, modified time, line count, and level counts.

```bash
wc -l "$LOGFILE"
grep -oE '\[(INFO|DEBUG|ERROR|WARNING|NOTICE)\]' "$LOGFILE" | sort | uniq -c | sort -rn
```

Then apply `$ARGUMENTS`:

| `$ARGUMENTS` | Show |
| --- | --- |
| *(empty)* | Last 20 lines, plus any error/fault lines |
| `errors` | Error and fault lines |
| `warnings` | Warning lines |
| `all` | The whole file |
| anything else | Treat as a search term; show matching lines |

## Read levels skeptically

Several call sites log success messages at `[ERROR]` - for example
`AudioPrewarmManager.swift:490` ("Input tap installed") and the
`AppGroupCoordinator` state-update lines, where all 30 "errors" in one capture
were routine status changes. **Report what a line says, not what its level
claims.** A raw error count is misleading on its own.

## Notes

- Logs are never deleted here; this only stops streams and summarizes.
- `logs/` is gitignored.

## Related

- [`logs-start`](../logs-start/SKILL.md)
