#!/bin/bash
# Launch VivaDicta on a connected physical device with print logging enabled
# and stream the console output to logs/device-<timestamp>.log.
#
# Usage:
#   ./scripts/launch_device.sh                 # auto-discover device + bundle id
#   ./scripts/launch_device.sh --check         # preflight only, do not launch
#   ./scripts/launch_device.sh --device <udid> # target a specific device
#   ./scripts/launch_device.sh --bundle <id>   # target a specific bundle id

set -uo pipefail

# Preferred first: a development build gives the freshest code under the console.
BUNDLE_CANDIDATES=(com.antonnovoselov.VivaDicta-beta com.antonnovoselov.VivaDicta)

DEVICE=""
BUNDLE_ID=""
CHECK_ONLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --check)  CHECK_ONLY=1; shift ;;
        --device) DEVICE="${2:-}"; shift 2 ;;
        --bundle) BUNDLE_ID="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Error: unknown argument '$1' (try --help)" >&2; exit 1 ;;
    esac
done

# --- Device discovery -------------------------------------------------------
# A device is eligible when it is real hardware (reality == physical), runs iOS,
# and has an active tunnel. Simulators are listed here too and must be excluded.
discover_device() {
    xcrun devicectl list devices -j - 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)["result"]["devices"]
except Exception:
    sys.exit(0)
for d in devices:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if (hw.get("reality") == "physical"
            and hw.get("platform") == "iOS"
            and conn.get("tunnelState") == "connected"):
        print("%s\t%s" % (hw.get("udid", d.get("identifier", "")),
                          d.get("deviceProperties", {}).get("name", "?")))
'
}

DEVICE_NAME=""
if [ -z "$DEVICE" ]; then
    MATCHES=$(discover_device)
    COUNT=$(printf '%s' "$MATCHES" | grep -c . )

    if [ "$COUNT" -eq 0 ]; then
        echo "Error: no connected physical iOS device found." >&2
        echo "       Plug in the device, unlock it, and trust this Mac." >&2
        echo "       Devices currently known to CoreDevice:" >&2
        xcrun devicectl list devices 2>/dev/null | sed 's/^/         /' >&2
        exit 1
    fi
    if [ "$COUNT" -gt 1 ]; then
        echo "Error: several connected devices; pass --device <udid>:" >&2
        printf '%s\n' "$MATCHES" | sed 's/^/         /' >&2
        exit 1
    fi

    DEVICE=$(printf '%s' "$MATCHES" | cut -f1)
    DEVICE_NAME=$(printf '%s' "$MATCHES" | cut -f2)
fi

# --- Bundle id resolution ---------------------------------------------------
# NOTE: --include-all-apps is required. Without it devicectl omits App Store and
# TestFlight installs, so an installed app looks missing.
installed_bundle_ids() {
    xcrun devicectl device info apps --device "$1" --include-all-apps -j - 2>/dev/null \
        | python3 -c '
import json, sys
try:
    apps = json.load(sys.stdin)["result"]["apps"]
except Exception:
    sys.exit(0)
for a in apps:
    print(a.get("bundleIdentifier", ""))
'
}

INSTALLED=$(installed_bundle_ids "$DEVICE")
if [ -z "$INSTALLED" ]; then
    echo "Error: could not read the app list from device $DEVICE." >&2
    echo "       Is it unlocked and still connected?" >&2
    exit 1
fi

if [ -n "$BUNDLE_ID" ]; then
    if ! grep -qxF "$BUNDLE_ID" <<<"$INSTALLED"; then
        echo "Error: '$BUNDLE_ID' is not installed on $DEVICE." >&2
        exit 1
    fi
else
    for candidate in "${BUNDLE_CANDIDATES[@]}"; do
        if grep -qxF "$candidate" <<<"$INSTALLED"; then BUNDLE_ID="$candidate"; break; fi
    done
    if [ -z "$BUNDLE_ID" ]; then
        echo "Error: no VivaDicta build is installed on $DEVICE." >&2
        echo "       Looked for: ${BUNDLE_CANDIDATES[*]}" >&2
        echo "       Build to the device from Xcode first, then re-run." >&2
        exit 1
    fi
fi

# A release/TestFlight build has no get-task-allow, so the console attach may be
# refused or silent. Say so up front rather than leaving an empty log file.
if [ "$BUNDLE_ID" = "com.antonnovoselov.VivaDicta" ]; then
    echo "Note: using the release bundle id ($BUNDLE_ID); the -beta dev build is not installed."
    echo "      Console output may be limited compared with a development build."
fi

echo "Device:  ${DEVICE_NAME:-$DEVICE} ($DEVICE)"
echo "Bundle:  $BUNDLE_ID"

if [ "$CHECK_ONLY" -eq 1 ]; then
    echo "Preflight OK (--check: not launching)."
    exit 0
fi

# --- Launch + capture -------------------------------------------------------
mkdir -p logs
LOGFILE="logs/device-$(date +%Y%m%d-%H%M%S).log"
echo "Logging: $LOGFILE"

xcrun devicectl device process launch \
    --console \
    --terminate-existing \
    --device "$DEVICE" \
    --environment-variables '{"ENABLE_PRINT_LOGS": "1"}' \
    "$BUNDLE_ID" 2>&1 | tee "$LOGFILE"
