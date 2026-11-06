#!/bin/bash
# Prints the UDID of an available iPhone simulator: a "Pro" model on the
# newest iOS runtime that has one, otherwise any iPhone on the newest runtime.
# Runner images add and drop device types with every Xcode update, so the
# workflows ask for "an iPhone" rather than pinning a device name and OS
# version that the next image may not have.
set -euo pipefail

xcrun simctl list devices available -j | python3 -c '
import json, re, sys

devices = json.load(sys.stdin)["devices"]
candidates = []
for runtime, entries in devices.items():
    match = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for entry in entries:
        name = entry["name"]
        if not name.startswith("iPhone"):
            continue
        is_pro = name.endswith(" Pro")
        candidates.append((version, is_pro, name, entry["udid"]))

if not candidates:
    sys.exit("No available iPhone simulator found")

version, _, name, udid = max(candidates, key=lambda c: (c[1], c[0], c[2]))
print(f"Using {name} on iOS {version[0]}.{version[1]} ({udid})", file=sys.stderr)
print(udid)
'
