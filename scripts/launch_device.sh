#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
xcrun devicectl device process launch \
    --console \
    --terminate-existing \
    --device 00008130-001250203C92001C \
    --environment-variables '{"ENABLE_PRINT_LOGS": "1"}' \
    com.antonnovoselov.VivaDicta 2>&1 | tee "logs/device-${TIMESTAMP}.log"
