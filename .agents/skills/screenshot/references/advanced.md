# Advanced Screenshot Options

## Capture from Specific Simulator

When multiple simulators are running, target by UDID:

```bash
SIMULATOR_UUID=$(xcrun simctl list devices | grep Booted | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
xcrun simctl io "$SIMULATOR_UUID" screenshot llmtemp/screenshots/screenshot.png
```

## Image Formats

```bash
xcrun simctl io booted screenshot --type=png llmtemp/screenshots/screenshot.png   # Default, lossless
xcrun simctl io booted screenshot --type=tiff llmtemp/screenshots/screenshot.tiff  # High quality
```

## Multiple Displays

For simulators with secondary displays (e.g., paired Apple Watch):

```bash
xcrun simctl io booted screenshot --display=1 llmtemp/screenshots/main.png    # Main display
xcrun simctl io booted screenshot --display=2 llmtemp/screenshots/watch.png   # Secondary
```

## Mask Sensitive Data

```bash
xcrun simctl io booted screenshot --mask=black llmtemp/screenshots/masked.png  # iOS 15+
```

## Common Workflows

### Screenshot After Automation

```bash
axe tap -x 195 -y 400 --udid $UDID
sleep 0.5  # Wait for animation
xcrun simctl io booted screenshot llmtemp/screenshots/after_tap.png
```

### Multiple Screenshots Sequence

```bash
mkdir -p llmtemp/screenshots
xcrun simctl io booted screenshot llmtemp/screenshots/step_01.png
# ... perform action ...
sleep 0.3
xcrun simctl io booted screenshot llmtemp/screenshots/step_02.png
```

### App Store Screenshots

```bash
mkdir -p llmtemp/screenshots/appstore
xcrun simctl io booted screenshot llmtemp/screenshots/appstore/iphone_6_7_inch_01.png
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "No such device: booted" | No simulator running | `xcrun simctl list devices \| grep Booted` |
| Blank/black screenshot | Content not loaded | Wait, ensure simulator is not minimized |
| Wrong simulator captured | Multiple booted sims | Use specific UDID instead of `booted` |
| "Invalid display" | No secondary display | Omit `--display` parameter |
