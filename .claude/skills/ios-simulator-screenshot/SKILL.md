---
name: ios-simulator-screenshot
description: Capture screenshots from iOS Simulator using native xcrun simctl command for documentation and debugging
---

# iOS Simulator Screenshot Capture

Use this skill when you need to capture screenshots from the iOS Simulator for documentation, debugging, or visual verification.

## Related Skills

- See [`axe-simulator-control.md`](./axe-simulator-control.md) for automating simulator interactions before capturing
- See [`xcodebuild-testing.md`](./xcodebuild-testing.md) for running tests that may require visual verification

## Skill Flow

- Example queries:
  - "take a screenshot of the simulator"
  - "capture the current simulator screen"
  - "screenshot the iOS simulator"
  - "save simulator screen to file"
- Notes:
  - Uses native `xcrun simctl` command for clean screenshots
  - No external dependencies (only Xcode required)
  - Captures framebuffer directly (clean, no simulator bezel)
  - Fast and lightweight
  - **Default screenshot directory**: `llmtemp/screenshots` in project root
  - Screenshots directory is gitignored and safe for temporary files

## Basic Usage

### Capture Screenshot from Booted Simulator

```bash
# Create screenshots directory if needed
mkdir -p llmtemp/screenshots

# Capture from booted simulator
xcrun simctl io booted screenshot llmtemp/screenshots/screenshot.png
```

**Parameters:**
- `booted` - Target the currently booted simulator (most common)
- Output path - Where to save the screenshot (PNG format)

**Result:**
- Clean screenshot without simulator frame/bezel
- PNG format (lossless quality)
- Fast capture directly from simulator framebuffer

## Advanced Usage

### Capture from Specific Simulator

If you have multiple simulators running, target a specific one by UDID:

```bash
# Get simulator UDID
SIMULATOR_UUID=$(axe list-simulators | grep Booted | head -1 | sed -E 's/.*- ([A-F0-9-]+).*/\1/')

# Or use specific UDID directly
SIMULATOR_UUID="D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75"

# Capture from specific simulator
xcrun simctl io "$SIMULATOR_UUID" screenshot llmtemp/screenshots/screenshot.png
```

### Specify Image Format

```bash
# PNG format (default, lossless)
xcrun simctl io booted screenshot --type=png llmtemp/screenshots/screenshot.png

# TIFF format (high quality)
xcrun simctl io booted screenshot --type=tiff llmtemp/screenshots/screenshot.tiff
```

### Capture Specific Display

For simulators with multiple displays (e.g., paired Apple Watch):

```bash
# Capture main display (default)
xcrun simctl io booted screenshot --display=1 llmtemp/screenshots/main_display.png

# Capture secondary display
xcrun simctl io booted screenshot --display=2 llmtemp/screenshots/watch_display.png
```

### Mask Private Information

When capturing screenshots that might contain sensitive data:

```bash
# Mask sensitive data (requires iOS 15+)
xcrun simctl io booted screenshot --mask=black llmtemp/screenshots/masked_screenshot.png

# Available mask options: black, ignored
```

## Common Workflows

### Quick Screenshot for Documentation

```bash
# 1. Ensure screenshots directory exists
mkdir -p llmtemp/screenshots

# 2. Capture current simulator state
xcrun simctl io booted screenshot llmtemp/screenshots/app_screenshot.png
```

### Screenshot After Automation

```bash
# 1. Use AXe to navigate to desired screen
axe tap -x 195 -y 400 --udid D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75
axe gesture scroll-up --udid D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75

# 2. Wait for animation to complete
sleep 0.5

# 3. Capture the result
xcrun simctl io booted screenshot llmtemp/screenshots/after_interaction.png
```

### Multiple Screenshots Sequence

```bash
# Ensure directory exists
mkdir -p llmtemp/screenshots

# Capture initial state
xcrun simctl io booted screenshot llmtemp/screenshots/screen_01_initial.png

# Perform action with AXe
axe tap -x 195 -y 400 --udid D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75
sleep 0.3

# Capture after interaction
xcrun simctl io booted screenshot llmtemp/screenshots/screen_02_after_tap.png

# Continue sequence
axe type 'test input' --udid D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75
sleep 0.3

xcrun simctl io booted screenshot llmtemp/screenshots/screen_03_after_input.png
```

### Screenshot with Timestamp

```bash
# Create timestamped filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
xcrun simctl io booted screenshot llmtemp/screenshots/screenshot_${TIMESTAMP}.png

# Or use date command inline
xcrun simctl io booted screenshot "llmtemp/screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png"
```

### Screenshot Different Device Sizes

```bash
# Get all booted simulators
xcrun simctl list devices | grep Booted

# Capture from specific device
xcrun simctl io "iPhone-15-Pro-UDID" screenshot llmtemp/screenshots/iphone15_pro.png
xcrun simctl io "iPad-Pro-UDID" screenshot llmtemp/screenshots/ipad_pro.png
```

### App Store Screenshots

```bash
# Create directory for App Store screenshots
mkdir -p llmtemp/screenshots/appstore

# Capture clean screenshots for different devices
# iPhone 6.7" display (iPhone 15 Pro Max, etc.)
xcrun simctl io booted screenshot llmtemp/screenshots/appstore/iphone_6_7_inch_01.png

# iPhone 6.5" display (iPhone 11 Pro Max, etc.)
xcrun simctl io booted screenshot llmtemp/screenshots/appstore/iphone_6_5_inch_01.png

# iPad Pro 12.9" display
xcrun simctl io booted screenshot llmtemp/screenshots/appstore/ipad_12_9_inch_01.png
```

## Screenshot Analysis with Claude

After capturing a screenshot, you can read and analyze it using Claude Code:

```bash
# 1. Capture screenshot
xcrun simctl io booted screenshot llmtemp/screenshots/current_screen.png

# 2. Read and analyze (Claude Code will process the image)
# Use the Read tool to view the screenshot
# Claude can then describe what's visible, extract text, check for UI elements, etc.
```

Example analysis tasks:
- "Is there a login button visible?"
- "What text is displayed on the screen?"
- "Are there any error messages?"
- "Describe the layout of this screen"
- "Extract all visible text"

## Troubleshooting

**"No such device: booted" error:**
- Ensure a simulator is running: `xcrun simctl list devices | grep Booted`
- Boot a simulator: `xcrun simctl boot <UDID>` or launch Simulator.app
- Check simulator status: `axe list-simulators`

**Screenshot is blank or black:**
- Ensure simulator window is visible and not minimized
- Wait for content to load before capturing
- Check simulator is not showing splash screen
- Verify app is fully launched

**"Invalid display" error:**
- Most simulators only have display 1 (main)
- Only use `--display=2` for devices with secondary displays (e.g., Apple Watch)
- Omit `--display` parameter to use default (main display)

**File not saved or path error:**
- Ensure `llmtemp/screenshots` directory exists: `mkdir -p llmtemp/screenshots`
- Use relative paths from project root
- Check file permissions in target directory
- Verify path doesn't contain special characters that need escaping

**Wrong simulator captured:**
- Use specific UDID instead of `booted`: `xcrun simctl io <UDID> screenshot ...`
- List booted simulators: `xcrun simctl list devices | grep Booted`
- Use AXe to verify UDID: `axe list-simulators`

**Screenshot contains simulator bezel:**
- This should NOT happen with `xcrun simctl` - it captures framebuffer only
- If you see a bezel, you may be using a different capture method
- Verify you're using `xcrun simctl io` command

## Best Practices

1. **Use descriptive file names** with timestamps or sequence numbers:
   ```bash
   xcrun simctl io booted screenshot "llmtemp/screenshots/login_screen_$(date +%Y%m%d_%H%M%S).png"
   ```

2. **Ensure directory exists** before capturing:
   ```bash
   mkdir -p llmtemp/screenshots
   ```

3. **Clean up old screenshots** after use:
   ```bash
   rm llmtemp/screenshots/screenshot_*.png
   # Or delete old files (older than 7 days)
   find llmtemp/screenshots -name "*.png" -mtime +7 -delete
   ```

4. **Combine with AXe automation** for reproducible screenshot sequences

5. **Wait for animations** before capturing:
   ```bash
   axe tap -x 195 -y 400 --udid D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75
   sleep 0.5  # Wait for animation
   xcrun simctl io booted screenshot llmtemp/screenshots/after_tap.png
   ```

6. **Store screenshots** in organized subdirectories:
   ```bash
   mkdir -p llmtemp/screenshots/login
   xcrun simctl io booted screenshot llmtemp/screenshots/login/step_1.png
   ```

7. **Use consistent simulator** for comparable screenshots:
   ```bash
   # Always use same simulator for feature screenshots
   SIMULATOR_UUID="D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75"
   xcrun simctl io "$SIMULATOR_UUID" screenshot llmtemp/screenshots/consistent.png
   ```

8. **Screenshots are gitignored** - the `llmtemp` directory is safe for temporary files

9. **Capture at consistent times**:
   ```bash
   # Wait for network requests to complete
   sleep 2
   xcrun simctl io booted screenshot llmtemp/screenshots/loaded_state.png
   ```

10. **Document screenshot purpose** in filenames or log files:
    ```bash
    # Use descriptive names
    xcrun simctl io booted screenshot llmtemp/screenshots/bug_123_reproduction.png
    xcrun simctl io booted screenshot llmtemp/screenshots/feature_xyz_final_state.png
    ```

## Comparison with Other Methods

| Feature | `xcrun simctl` | Window Capture Tools |
|---------|----------------|----------------------|
| Capture type | Framebuffer (clean) | Window (with bezel) |
| Speed | ⚡ Fast | Slower |
| Dependencies | Xcode only | Additional tools |
| Output quality | Clean, no bezel | Includes simulator frame |
| Multiple simulators | ✅ Yes (by UDID) | ✅ Yes (by app name) |
| Built-in analysis | ❌ No | ✅ Some tools |
| Best for | Documentation, testing | Developer screenshots |

**Recommendation:** Use `xcrun simctl` for all iOS Simulator screenshot needs - it's fast, clean, and has no external dependencies.
