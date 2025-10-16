#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SIMULATOR_UUID=$(xcrun simctl list devices | grep "(Booted)" | grep -o '[0-9A-F]\{8\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{12\}' | head -1)

if [ -z "$SIMULATOR_UUID" ]; then
    echo "Error: No booted simulator found"
    exit 1
fi

xcrun simctl spawn "$SIMULATOR_UUID" log stream \
    --level=debug \
    --predicate 'subsystem == "com.antonnovoselov.VivaDicta"' \
    2>&1 | tee "logs/sim-${TIMESTAMP}.log"
