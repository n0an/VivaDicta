#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
APP_BUNDLE_ID="com.antonnovoselov.VivaDicta-beta"

xcrun devicectl device process launch \
    --console \
    --terminate-existing \
    --device 00008130-001250203C92001C \
    --environment-variables '{"ENABLE_PRINT_LOGS": "1"}' \
    "$APP_BUNDLE_ID" 2>&1 | tee "logs/device-${TIMESTAMP}.log"
