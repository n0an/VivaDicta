---
name: logs-stop
description: Stop whichever VivaDicta log capture is active, then summarize it. Detects the tier itself; takes an optional filter.
disable-model-invocation: true
---

# logs-stop

Stop the active capture(s) started by [`logs-start`](../logs-start/SKILL.md) and
summarize the result. **Never ask the user which tier is running - detect it.**

## Step 1: detect

`logs-start` writes a marker per live tier naming the process that streams:
`logs/.sim-capture.pid` and `logs/.device-capture.pid`. Read those - do not go
looking for processes.

```bash
for tier in sim device; do
  PIDFILE="logs/.${tier}-capture.pid"
  [ -f "$PIDFILE" ] || continue
  PID=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "$tier ACTIVE (pid $PID)"
  else
    echo "$tier marker stale (pid ${PID:-none} gone), removing"
    rm -f "$PIDFILE"
  fi
done
[ -f llmtemp/.device-log-start-time ] && echo "structured PENDING: $(cat llmtemp/.device-log-start-time)"
```

`structured` has no process - a marker file is the only evidence. If nothing is
found, say so plainly and stop; do not summarize a stale file as if it were
fresh.

### Never detect or stop a capture by process pattern

The obvious-looking check is wrong and it is destructive:

```bash
pgrep -f "simctl spawn.*log stream"     # matches ANY simulator log stream on the machine
```

That pattern is not specific to this repo, this app, or this capture. It matches
an unrelated `log stream` any other session has running, reports `sim ACTIVE`
when no VivaDicta capture exists, and the matching `pkill` then kills that
session's stream. A capture the user never started must never be stopped, so the
marker is the only handle.

Two related traps, if you ever debug this by hand:

- **`pgrep -a` is not a macOS flag.** `pgrep` here accepts only `[-Lfilnoqvx]`,
  yet `-a` exits 0 and prints a bogus pid rather than erroring. Use plain `-f`.
- **`grep` for a pattern matches your own pipeline.** `ps -A | grep "log stream"`
  counts the greps themselves, because both carry the string in their own argv.
  Add `| grep -v grep`, or check the marker instead.

## Step 2: stop and summarize each active tier

Kill the **streaming** process the marker names. Do not kill the wrapper script:
`launch_*.sh` is the parent of the stream, and killing the parent reparents the
stream to PID 1, where it keeps appending to the log file with nothing left to
stop it. Killing the stream is enough - the script's `tee` then reaches EOF and
the script exits, clearing its own marker.

### sim

```bash
PID=$(cat logs/.sim-capture.pid)
ps -p "$PID" -o command= | grep -q "log stream" || echo "refusing: pid $PID is not a log stream"
kill "$PID"
LOGFILE=$(ls -t logs/sim-*.log 2>/dev/null | head -1)
```

### device

```bash
PID=$(cat logs/.device-capture.pid)
ps -p "$PID" -o command= | grep -q "devicectl device process launch" || echo "refusing: pid $PID is not a device capture"
kill "$PID"
LOGFILE=$(ls -t logs/device-*.log 2>/dev/null | head -1)
```

The `ps` check is there because a pid can be reused. If the command line does not
match, say so and stop rather than killing an unrelated process.

The capture ends with `App terminated due to signal 15` - that is this skill's
`kill`, not a crash. Say so rather than reporting it as a failure.

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



**Hand them a line they can paste, not a description of one.** In Claude Code, a
prompt starting with `!` runs in the session and its output lands back in the
conversation, so the whole handoff is one copy-paste. Print exactly this, on its
own line, as the last thing before you stop:

```
! ./scripts/collect_device_logs.sh
```

Do not write it as a bare `./scripts/collect_device_logs.sh` and explain that
sudo is needed - that reads as "go and do this in a terminal somewhere", and the
result then has to be pasted back by hand. The `!` prefix is the part that makes
it work in place, and it is not obvious unless it is shown.

Then wait for confirmation and read the newest export:

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
