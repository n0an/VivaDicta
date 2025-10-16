# screenshot

You are given the following context:
ARGUMENTS: {{ARGS}}

## Task

Capture a screenshot of the iOS Simulator using Peekaboo MCP and optionally analyze it based on user instructions.

## Instructions

1. **Check if the screenshots directory exists**, if not create it:
   ```bash
   mkdir -p llmtemp/screenshots
   ```

2. **Capture the screenshot** using Peekaboo MCP with these settings:
   - Path: `llmtemp/screenshots/screenshot_<timestamp>.png` (use current timestamp for uniqueness)
   - Format: `png`
   - App target: `"Simulator"`
   - Capture focus: `"background"` (to prevent window focus changes)

3. **Handle the optional argument**:
   - **If ARGS is empty or not provided**: Simply capture and save the screenshot, then report the saved path
   - **If ARGS is provided**: After capturing and saving the screenshot, read the screenshot file and follow the instructions in ARGS

   Common argument patterns:
   - "take a look" / "analyze" / "what's on screen" → Read and describe what's visible
   - "check for [element]" → Look for specific UI elements
   - "is there [something]" → Verify presence of specific content
   - "extract text" → Extract and list all visible text
   - Any other instruction → Follow it after reading the screenshot

4. **Report results**:
   - Always mention the saved screenshot path
   - If analyzed, provide your findings based on the ARGS instruction

## Example Usage

```bash
# Simple capture (no analysis)
/screenshot

# Capture and analyze
/screenshot take a look

# Capture and check for specific element
/screenshot is there a login button?

# Capture and extract text
/screenshot extract all visible text
```

## Technical Notes

- Uses the `ios-simulator-screenshot.md` skill for reference
- Screenshots are saved to `llmtemp/screenshots` (gitignored directory)
- Filenames include timestamps to prevent overwrites
- Always uses `capture_focus="background"` for non-intrusive capture
