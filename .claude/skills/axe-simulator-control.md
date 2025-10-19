# AXe Simulator Control

Use this skill when you need to automate iOS Simulator interactions, including taps, gestures, text input, hardware buttons, or video recording.

## Related Skills

- See [`xcodebuild-testing.md`](./xcodebuild-testing.md) for running tests that might require simulator interactions
- See [`ios-ui-testing.md`](./ios-ui-testing.md) if you need to write UI tests instead of direct simulator control

## Additional Resources

- [AXe Documentation](../../docs/Tools/Axe_README.md) - Complete AXe reference including advanced features, architecture, and troubleshooting

## Skill Flow

- Example queries:
  - "tap at coordinates (100, 200) in the simulator"
  - "type 'hello world' into the simulator"
  - "press the home button in the simulator"
  - "record a video of the simulator"
  - "perform a scroll up gesture"
- Notes:
  - AXe is installed via Homebrew: `brew tap cameroncooke/axe && brew install axe`
  - Most commands require a simulator UDID (use `axe list-simulators` to find it)
  - The simulator must be booted and running for most operations
  - AXe uses the iOS Simulator's accessibility framework
  - For VivaDicta project, the default simulator is: `iPhone 17 Pro, OS=26.0`
  - Save screenshots to `llmtemp/screenshots/` directory for temporary test artifacts

### 1. Determine the Required Action

**Touch/Tap Actions** if:
- Need to tap at specific coordinates
- Need to add delays before/after taps
- Need to simulate touch gestures

→ Continue with **Path A: Touch & Tap** (steps 2A-4A)

**Text Input** if:
- Need to type text into the simulator
- Need to test keyboard input
- Need to simulate user text entry

→ Continue with **Path B: Text Input** (step 2B)

**Gestures** if:
- Need to scroll, swipe, or perform system gestures
- Need to test gesture recognizers
- Need to navigate using gestures

→ Continue with **Path C: Gestures** (steps 2C-3C)

**Hardware Buttons** if:
- Need to press home, lock, volume buttons
- Need to test app lifecycle events
- Need to simulate device rotation

→ Continue with **Path D: Hardware Buttons** (steps 2D-3D)

**Video Operations** if:
- Need to record simulator video
- Need to stream simulator output
- Need to capture simulator for documentation

→ Continue with **Path E: Video Operations** (steps 2E-3E)

**List Simulators** if:
- Need to find available simulators
- Need to get a simulator UDID
- First time setup

→ Continue with **Path F: List Simulators** (step 2F)

## Path A: Touch & Tap

### 2A. Get Simulator UDID

```bash
# List available simulators
axe list-simulators

# Store the UDID for the target simulator
UDID="B34FF305-5EA8-412B-943F-1D0371CA17FF"
```

### 3A. Get Accurate Coordinates Using describe-ui

**IMPORTANT:** Always use `axe describe-ui` to get accurate coordinates instead of guessing from screenshots.

```bash
# Get the full UI accessibility tree
axe describe-ui --udid $UDID > ui_tree.json

# Example output for a button:
# {
#   "AXFrame" : "{{175, 741}, {52, 50}}",
#   "AXLabel" : "stop.circle.fill",
#   "type" : "Button",
#   ...
# }

# Calculate center coordinates:
# x_center = x + (width / 2)  →  175 + (52 / 2) = 201
# y_center = y + (height / 2)  →  741 + (50 / 2) = 766
```

**Why this matters:**
- Visual appearance in screenshots doesn't always match accessibility frame coordinates
- UI elements that change state (e.g., record → stop button) may have different positions than they appear
- The accessibility frame is what AXe actually uses for tap detection

### 4A. Perform Tap Action

```bash
# Simple tap at coordinates (use coordinates from describe-ui)
axe tap -x 201 -y 766 --udid $UDID

# Tap with delays before and after
axe tap -x 201 -y 766 --pre-delay 1.0 --post-delay 0.5 --udid $UDID
```

**Available tap options:**
- `-x` and `-y`: Coordinates (required) - get these from `describe-ui` output
- `--pre-delay`: Delay in seconds before tapping
- `--post-delay`: Delay in seconds after tapping
- `--udid`: Simulator UDID (required)

**Note:** The `tap` command does NOT support `--duration` for long press. Use `--pre-delay` and `--post-delay` for timing control.

### 5A. Verify the Action

- Check the simulator visually or via app logs
- If tap didn't register, ensure:
  - Simulator is in foreground
  - Coordinates are correct (origin is top-left)
  - Target element is interactive
  - You used coordinates from `describe-ui`, not visual estimates

## Path B: Text Input

### 2B. Type Text into Simulator

```bash
# Get simulator UDID first
UDID="B34FF305-5EA8-412B-943F-1D0371CA17FF"

# Type text (ensure a text field is focused first)
axe type 'Hello World!' --udid $UDID

# Type text with special characters (use single quotes)
axe type 'user@example.com' --udid $UDID
```

**Notes:**
- The text field must be focused before typing (tap it first if needed)
- Use single quotes to avoid shell interpretation
- Special characters and emojis are supported

## Path C: Gestures

### 2C. Choose Gesture Type

Available gestures:
- `scroll-up` / `scroll-down` / `scroll-left` / `scroll-right`
- `swipe-from-left-edge` / `swipe-from-right-edge`
- `swipe-from-top-edge` / `swipe-from-bottom-edge`

### 3C. Execute Gesture

```bash
# Get simulator UDID first
UDID="B34FF305-5EA8-412B-943F-1D0371CA17FF"

# Perform scroll gesture
axe gesture scroll-up --udid $UDID

# Perform edge swipe (for navigation)
axe gesture swipe-from-left-edge --udid $UDID

# Perform swipe gesture
axe gesture swipe-from-bottom-edge --udid $UDID
```

## Path D: Hardware Buttons

### 2D. Choose Button Action

Available buttons:
- `home` - Press home button
- `lock` - Press lock/power button
- `volume-up` / `volume-down`
- `siri` - Activate Siri

### 3D. Execute Button Press

```bash
# Get simulator UDID first
UDID="B34FF305-5EA8-412B-943F-1D0371CA17FF"

# Press home button
axe button home --udid $UDID

# Press lock button with custom duration
axe button lock --duration 2.0 --udid $UDID

# Press volume up
axe button volume-up --udid $UDID
```

**Notes:**
- Lock duration determines press-and-hold behavior
- Home button triggers app backgrounding
- Use for testing app lifecycle events

## Path E: Video Operations

### 2E. Choose Operation Type

**Stream Video** if:
- Need real-time video output
- Building automation tools
- Need MJPEG format

**Record Video** if:
- Need to save video file
- Creating documentation
- Need MP4 format

### 3E. Execute Video Operation

**Stream Video:**
```bash
UDID="B34FF305-5EA8-412B-943F-1D0371CA17FF"

# Stream at 10 FPS in MJPEG format
axe stream-video --udid $UDID --fps 10 --format mjpeg > stream.mjpeg
```

**Record Video:**
```bash
UDID="B34FF305-5EA8-412B-943F-1D0371CA17FF"

# Record at 15 FPS and save to file
axe record-video --udid $UDID --fps 15 --output recording.mp4

# Stop recording with Ctrl+C
```

## Path F: List Simulators

### 2F. List Available Simulators

```bash
# List all available simulators with their UDIDs
axe list-simulators

# Example output:
# iPhone 17 Pro (26.0) - B34FF305-5EA8-412B-943F-1D0371CA17FF
# iPhone 16 (25.0) - A12BC456-7DEF-89GH-IJKL-MNOPQRSTUVWX
```

**Notes:**
- Copy the UDID for use in other commands
- Only booted simulators can be controlled
- Use `xcrun simctl list` for more detailed simulator information

## Common Workflows

### Automated Testing Workflow

```bash
# 1. Get the simulator UDID
UDID=$(axe list-simulators | grep "iPhone 17 Pro" | awk '{print $NF}')

# 2. Tap to focus text field
axe tap -x 200 -y 300 --udid $UDID

# 3. Type text
axe type 'test@example.com' --udid $UDID

# 4. Tap submit button
axe tap -x 200 -y 400 --udid $UDID

# 5. Wait and verify (app-specific)
```

### Video Documentation Workflow

```bash
# 1. Get simulator UDID
UDID="B34FF305-5EA8-412B-943F-1D0371CA17FF"

# 2. Start recording
axe record-video --udid $UDID --fps 30 --output demo.mp4 &
RECORD_PID=$!

# 3. Perform actions
axe tap -x 100 -y 200 --udid $UDID
sleep 1
axe gesture scroll-up --udid $UDID
sleep 1
axe button home --udid $UDID

# 4. Stop recording
kill $RECORD_PID
```

## Known Limitations

### SwiftUI TabView Navigation

**Issue:** SwiftUI's modern `TabView` component (iOS 18+) doesn't expose individual tab buttons in the accessibility hierarchy.

**What you'll see:**
- `axe describe-ui` shows the tab bar as a single `AXGroup` with no children
- Individual tab buttons are NOT listed as separate accessible elements

**Example:**
```json
{
  "AXFrame" : "{{0, 791}, {402, 83}}",
  "AXLabel" : "Tab Bar",
  "type" : "Group",
  "children" : []  // ← No individual tab buttons exposed
}
```

**✅ However, tab navigation DOES work with calculated coordinates!**

Even though tab buttons aren't in the accessibility tree, you can still tap them using estimated positions within the Tab Bar frame:

```bash
# Tab Bar frame: x: 0, y: 791, width: 402, height: 83
# Calculate y-center: 791 + (83/2) = 832

# For a 3-tab layout (Record, Notes, Settings):
UDID="D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75"

# Tap Record tab (left third)
axe tap -x 103 -y 832 --udid $UDID    # x ≈ 402 * 1/4

# Tap Notes tab (center)
axe tap -x 201 -y 832 --udid $UDID    # x ≈ 402 * 1/2

# Tap Settings tab (right third)
axe tap -x 268 -y 832 --udid $UDID    # x ≈ 402 * 2/3
```

**Key insight:** The Tab Bar frame tells you the tappable area. Calculate positions by:
1. Get y-center from frame: `y + (height / 2)`
2. Divide x-axis by number of tabs to estimate positions
3. Test and adjust x-coordinates based on actual tab spacing

**Alternative workarounds:**
- Use XCUITest for UI testing that requires guaranteed tab detection
- Add custom accessibility identifiers if you control the app code
- Use deep linking or keyboard shortcuts for tab navigation in automation

### Other SwiftUI Components

Some SwiftUI components may have limited accessibility exposure. Always use `axe describe-ui` to verify an element is accessible before attempting to interact with it.

## Troubleshooting

**"Simulator not found" error:**
- Ensure simulator is booted: `xcrun simctl list | grep Booted`
- Verify UDID is correct: `axe list-simulators`

**Tap not registering:**
- **FIRST:** Use `axe describe-ui` to get accurate coordinates (don't guess from screenshots)
- Check coordinates are within screen bounds
- Ensure element is visible and interactive
- Verify the element appears in the accessibility tree with `describe-ui`
- Try adding small delay between taps

**Text not appearing:**
- Tap text field first to focus it
- Check keyboard is visible in simulator
- Verify text encoding with single quotes

**Video recording issues:**
- Ensure sufficient disk space
- Check file permissions in output directory
- Verify FPS is reasonable (10-30 recommended)
