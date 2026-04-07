---
name: screenshot
description: Capture screenshots from iOS Simulator using native xcrun simctl command for documentation, debugging, and visual verification. Optionally analyze the screenshot.
disable-model-invocation: true
---

# screenshot

You are given the following context:
$ARGUMENTS

## Task

Capture a screenshot of the iOS Simulator using `xcrun simctl` and optionally analyze it based on user instructions.

## Instructions

1. **Create screenshots directory** if needed:
   ```bash
   mkdir -p llmtemp/screenshots
   ```

2. **Capture the screenshot**:
   ```bash
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   xcrun simctl io booted screenshot llmtemp/screenshots/screenshot_${TIMESTAMP}.png
   ```

3. **Handle the optional argument**:
   - **If `$ARGUMENTS` is empty or not provided**: Capture and save, then report the saved path
   - **If `$ARGUMENTS` is provided**: After saving, read the screenshot and follow the requested instruction

   Common argument patterns:
   - "take a look" / "analyze" / "what's on screen" - Read and describe what's visible
   - "check for [element]" - Look for specific UI elements
   - "is there [something]" - Verify presence of specific content
   - "extract text" - Extract and list all visible text
   - Any other instruction - Follow it after reading the screenshot

4. **Report results**: Always mention the saved screenshot path. If analyzed, provide findings.

## Example Usage

```bash
screenshot                              # Simple capture
screenshot take a look                  # Capture and analyze
screenshot is there a login button?     # Check for specific element
screenshot extract all visible text     # Extract text
```

## Advanced Options

For advanced use cases, load `references/advanced.md`.

- **Specific simulator**: Use UDID instead of `booted` when multiple simulators are running
- **Image format**: `--type=png` (default), `--type=tiff`
- **Specific display**: `--display=1` (main), `--display=2` (secondary, e.g. Apple Watch)
- **Mask sensitive data**: `--mask=black` (iOS 15+)

## Troubleshooting

- **"No such device: booted"**: No simulator running. Check with `xcrun simctl list devices | grep Booted`
- **Blank/black screenshot**: Wait for content to load, ensure simulator is not minimized
- **Wrong simulator captured**: Use specific UDID instead of `booted`

## Technical Notes

- Screenshots saved to `llmtemp/screenshots` (gitignored)
- Filenames include timestamps to prevent overwrites
- Native `xcrun simctl` command - no external dependencies, only Xcode
- Captures clean framebuffer without simulator bezel
- PNG format (lossless)
