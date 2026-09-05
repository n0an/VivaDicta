#!/bin/bash

# Device log collection script
# This script requires sudo access and will prompt for your password

# Resolve project root (directory containing this script's parent)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

# Read timestamp and UDID from temp files
if [ ! -f "llmtemp/.device-log-start-time" ] || [ ! -f "llmtemp/.device-log-udid" ]; then
  echo "Error: Start timestamp or UDID not found."
  echo "Please run the start-logs-device-structured skill first."
  exit 1
fi

# Ensure logs directory exists
mkdir -p logs

START_TIME=$(cat llmtemp/.device-log-start-time)
UDID=$(cat llmtemp/.device-log-udid)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGARCHIVE="logs/vivadicta_device_${TIMESTAMP}.logarchive"
LOGFILE="logs/device_${TIMESTAMP}.txt"

echo "Collecting device logs from device"
echo "Start time: ${START_TIME}"
echo "UDID: ${UDID}"
echo ""
echo "This will prompt for your sudo password..."
echo ""

# Collect logs from device
sudo log collect \
  --device-udid "${UDID}" \
  --start "${START_TIME}" \
  --output "${LOGARCHIVE}"

if [ $? -eq 0 ]; then
  echo ""
  echo "✓ Log archive collected: ${LOGARCHIVE}"
  echo ""
  echo "Extracting VivaDicta logs..."

  # Extract and filter logs
  log show "${LOGARCHIVE}" \
    --predicate 'subsystem == "com.antonnovoselov.VivaDicta"' \
    --info \
    --style compact > "${LOGFILE}"

  echo "✓ Filtered logs saved: ${LOGFILE}"
  echo ""

  # Show summary
  TOTAL_LINES=$(wc -l < "${LOGFILE}")
  # grep -c prints the count AND exits 1 when it is zero, so a `|| echo 0`
  # fallback appends a second line and yields "0\n0". Let grep's own output
  # stand and neutralize only the exit status.
  ERRORS=$(grep -ic "error" "${LOGFILE}"; true)
  WARNINGS=$(grep -ic "warning" "${LOGFILE}"; true)

  echo "Summary:"
  echo "  Total log entries: ${TOTAL_LINES}"
  echo "  Errors: ${ERRORS}"
  echo "  Warnings: ${WARNINGS}"
  echo ""

  if [ "${ERRORS}" -gt 0 ] || [ "${WARNINGS}" -gt 0 ]; then
    echo "Recent errors/warnings:"
    grep -iE "error|warning" "${LOGFILE}" | tail -20
  fi

  # Clean up temp files
  rm -f llmtemp/.device-log-start-time
  rm -f llmtemp/.device-log-udid

  echo ""
  echo "✓ Log collection complete!"
  echo ""
  echo "To analyze further:"
  echo "  • View text logs: cat ${LOGFILE}"
  echo "  • Open in Console.app: open ${LOGARCHIVE}"
else
  echo "✗ Log collection failed"
  exit 1
fi
