#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SIMULATOR_UUID=$(xcrun simctl list devices | grep "(Booted)" | grep -o '[0-9A-F]\{8\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{12\}' | head -1)

if [ -z "$SIMULATOR_UUID" ]; then
    echo "Error: No booted simulator found"
    exit 1
fi

# Record the STREAMING process, not this shell, and take it down on the way out.
#
# A capture is two processes: this script, and the `simctl spawn` doing the streaming. Killing the
# script alone reparents that child to PID 1, where it keeps writing to the log file with nothing
# left to stop it. So the pid that matters to logs-stop is the child's, and process substitution is
# what makes `$!` refer to it instead of to `tee`.
#
# The marker file also lets logs-stop end the tier that was actually started, rather than matching
# `simctl spawn.*log stream` against every process on the machine - a pattern that also catches
# unrelated simulator log streams and would kill someone else's debugging session.
PIDFILE="logs/.sim-capture.pid"

cleanup() {
    trap - EXIT INT TERM
    if [ -n "${STREAM_PID:-}" ]; then
        kill "$STREAM_PID" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
}
trap cleanup EXIT INT TERM

xcrun simctl spawn "$SIMULATOR_UUID" log stream \
    --level=debug \
    --predicate 'subsystem == "com.antonnovoselov.VivaDicta"' \
    > >(tee "logs/sim-${TIMESTAMP}.log") 2>&1 &
STREAM_PID=$!
printf '%s\n' "$STREAM_PID" > "$PIDFILE"
wait "$STREAM_PID" || true
