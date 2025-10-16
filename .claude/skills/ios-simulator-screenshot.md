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
  - Uses Peekaboo MCP server for screenshot capture
  - Captures without changing window focus (non-intrusive)
  - Supports PNG format output
  - Can capture specific app windows or frontmost application
  - Optional AI analysis of captured images
  - **Default screenshot directory**: `llmtemp/screenshots` in project root
  - Screenshots directory is gitignored and safe for temporary files

### 1. Determine Capture Target

**Frontmost Window** if:
- Need to capture whatever is currently visible
- Simulator is the active application
- Quick capture without specifying target

→ Continue with **Path A: Frontmost Capture** (step 2A)

**Specific Application** if:
- Need to target simulator specifically by name
- Multiple applications open
- Want explicit control over target

→ Continue with **Path B: App-Targeted Capture** (step 2B)

**With AI Analysis** if:
- Need to understand what's in the screenshot
- Want to extract text or UI elements
- Need automated visual verification

→ Continue with **Path C: Capture with Analysis** (step 2C)

## Path A: Frontmost Capture

### 2A. Capture Frontmost Window

Use the Peekaboo MCP `image` tool to capture the frontmost application:

```python
# Using MCP tool directly
mcp__peekaboo__image(
    path="llmtemp/screenshots/simulator_screenshot.png",
    format="png",
    app_target="frontmost",
    capture_focus="background"
)
```

**Parameters:**
- `path`: Output file path (absolute path recommended)
- `format`: Output format (`png`, `jpg`, or `data` for Base64)
- `app_target`: Set to `"frontmost"` for active window
- `capture_focus`: Set to `"background"` to prevent window focus changes (recommended)

**Result:**
- Screenshot saved to specified path
- No focus change to simulator (when using `capture_focus="background"`)
- Returns confirmation message

## Path B: App-Targeted Capture

### 2B. Capture Specific Application

Target the iOS Simulator specifically by application name:

```python
# Using MCP tool with app name
mcp__peekaboo__image(
    path="llmtemp/screenshots/simulator_screenshot.png",
    format="png",
    app_target="Simulator",
    capture_focus="background"
)
```

**Common iOS Simulator targets:**
- `"Simulator"` - The iOS Simulator app (most common)
- `"frontmost"` - Whatever app is currently active
- `""` (empty string) - All screens

**Tips:**
- Use `"Simulator"` to specifically target iOS Simulator
- App names are case-sensitive
- Peekaboo will capture all windows of the specified app

## Path C: Capture with Analysis

### 2C. Capture and Analyze Screenshot

Capture a screenshot and ask AI to analyze its contents:

```python
# Capture with AI analysis
mcp__peekaboo__image(
    path="llmtemp/screenshots/simulator_screenshot.png",
    format="png",
    app_target="frontmost",
    capture_focus="background",
    question="What UI elements are visible on the screen?"
)
```

**Analysis use cases:**
- Extract visible text from screenshot
- Verify UI layout and elements
- Identify button states or labels
- Check for error messages
- Validate screen content

**Example questions:**
- "What text is displayed on the screen?"
- "Are there any error messages visible?"
- "What buttons are shown in the navigation bar?"
- "Describe the layout of this screen"

## Common Workflows

### Quick Screenshot for Documentation

```python
# 1. Capture current simulator state
mcp__peekaboo__image(
    path="llmtemp/screenshots/app_screenshot.png",
    format="png",
    app_target="frontmost",
    capture_focus="background"
)
```

### Screenshot After Automation

```bash
# 1. Use AXe to navigate to desired screen
axe tap -x 195 -y 400 --udid D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75
axe gesture scroll-up --udid D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75

# 2. Capture the result with Peekaboo MCP
```

```python
mcp__peekaboo__image(
    path="llmtemp/screenshots/after_interaction.png",
    format="png",
    app_target="Simulator",
    capture_focus="background"
)
```

### Visual Test Verification

```python
# 1. Capture screenshot with analysis
mcp__peekaboo__image(
    path="llmtemp/screenshots/login_screen.png",
    format="png",
    app_target="Simulator",
    capture_focus="background",
    question="Is there a 'Login' button visible on the screen?"
)

# 2. AI will analyze and respond with findings
# 3. Use response to verify test expectations
```

### Multiple Screenshots Sequence

```python
# Capture initial state
mcp__peekaboo__image(
    path="llmtemp/screenshots/screen_01_initial.png",
    format="png",
    app_target="Simulator",
    capture_focus="background"
)

# Perform action with AXe (in bash)
# axe tap -x 195 -y 400 --udid <UDID>

# Capture after interaction
mcp__peekaboo__image(
    path="llmtemp/screenshots/screen_02_after_tap.png",
    format="png",
    app_target="Simulator",
    capture_focus="background"
)
```

## Output Formats

### PNG (Default)
```python
mcp__peekaboo__image(
    path="llmtemp/screenshots/screenshot.png",
    format="png",
    app_target="frontmost",
    capture_focus="background"
)
```
- Best for documentation
- Lossless quality
- Larger file size

### JPEG
```python
mcp__peekaboo__image(
    path="llmtemp/screenshots/screenshot.jpg",
    format="jpg",
    app_target="frontmost",
    capture_focus="background"
)
```
- Smaller file size
- Lossy compression
- Good for web usage

### Base64 Data
```python
mcp__peekaboo__image(
    path="llmtemp/screenshots/screenshot.png",
    format="data",
    app_target="frontmost",
    capture_focus="background"
)
```
- Returns Base64 encoded image data
- Useful for embedding in JSON/API responses
- Can still save to file if path is provided

## Troubleshooting

**Screenshot is blank or black:**
- Ensure iOS Simulator is actually running and visible
- Check that simulator window is not minimized
- Verify simulator has content displayed (not loading screen)

**Wrong window captured:**
- Use `app_target="Simulator"` instead of `"frontmost"`
- Make sure simulator is the active window
- Check for multiple simulator instances

**File not found error:**
- Ensure `llmtemp/screenshots` directory exists in project root
- Use relative paths from project root: `llmtemp/screenshots/screenshot.png`
- Create directory if needed: `mkdir -p llmtemp/screenshots`
- Check file permissions

**Capture focus changes:**
- Always use `capture_focus="background"` to prevent window focus changes
- Without this parameter, the simulator window may be brought to front
- This is especially important when capturing during automation sequences

## Best Practices

1. **Use descriptive file names** with timestamps or sequence numbers:
   ```python
   path=f"llmtemp/screenshots/simulator_{test_name}_{timestamp}.png"
   ```

2. **Ensure directory exists** before capturing:
   ```bash
   mkdir -p llmtemp/screenshots
   ```

3. **Clean up old screenshots** after use:
   ```bash
   rm llmtemp/screenshots/simulator_*.png
   ```

4. **Combine with AXe automation** for reproducible screenshot sequences

5. **Use AI analysis** for automated visual verification instead of manual checking

6. **Store screenshots** in organized subdirectories:
   ```python
   path="llmtemp/screenshots/login/step_1.png"
   ```

7. **Specify simulator explicitly** when multiple apps are open:
   ```python
   app_target="Simulator"  # More reliable than "frontmost"
   ```

8. **Screenshots are gitignored** - the `llmtemp` directory is safe for temporary files
