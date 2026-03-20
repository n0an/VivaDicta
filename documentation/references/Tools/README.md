# CLI Tools Used in VivaDicta

This directory contains documentation for command-line tools used in this project. These are standalone CLI tools that integrate with the development workflow, distinct from MCP servers.

## Active CLI Tools

### AXe
- **Purpose**: iOS Simulator automation and control
- **Docs**: [Axe_README.md](./Axe_README.md)
- **Repository**: https://github.com/cameroncooke/AXe
- **Installation**: Homebrew (`brew tap cameroncooke/axe && brew install axe`)

**Available Commands:**
- `axe list-simulators` - List available iOS Simulators with UDIDs
- `axe tap` - Tap at specific coordinates
  - Options: `-x`, `-y`, `--pre-delay`, `--post-delay`, `--udid`
- `axe type` - Type text into focused text field
  - Requires text field to be focused first
- `axe gesture` - Perform system gestures
  - `scroll-up`, `scroll-down`, `scroll-left`, `scroll-right`
  - `swipe-from-left-edge`, `swipe-from-right-edge`
  - `swipe-from-top-edge`, `swipe-from-bottom-edge`
- `axe button` - Simulate hardware button presses
  - `home`, `lock`, `volume-up`, `volume-down`, `siri`
- `axe stream-video` - Stream simulator video output
- `axe record-video` - Record simulator video to file

**Primary Use Cases:**
- Automated UI testing without XCTest
- Script-based simulator interactions
- Recording demo videos
- Gesture-based navigation testing
- Reproducible UI interaction sequences

**Integration:**
- Called via Bash tool from Claude Code
- Used in combination with xcrun simctl for capture-after-interaction workflows
- Requires simulator UDID (obtained via `axe list-simulators`)

**Related Skills:**
- [axe-simulator-control.md](../../.claude/skills/axe-simulator-control.md)

**Common Patterns:**
```bash
# Get simulator UDID
UDID="D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75"

# Tap and type workflow
axe tap -x 200 -y 300 --udid $UDID
axe type 'test@example.com' --udid $UDID
axe tap -x 200 -y 400 --udid $UDID

# Navigation gestures
axe gesture swipe-from-left-edge --udid $UDID
axe gesture scroll-up --udid $UDID
axe button home --udid $UDID
```

**Notes:**
- Simulator must be booted for commands to work
- Coordinates use top-left origin (0,0)
- For VivaDicta project, default simulator: iPhone 17 Pro (iOS 26.0)
- No `--duration` option for tap (use `--pre-delay`/`--post-delay`)

---

### xcrun simctl
- **Purpose**: Native iOS Simulator control and management
- **Docs**: Built into Xcode
- **Installation**: Included with Xcode Command Line Tools

**Available Commands:**
- `xcrun simctl list` - List all simulators and devices
- `xcrun simctl boot <UDID>` - Boot a specific simulator
- `xcrun simctl shutdown <UDID>` - Shutdown a simulator
- `xcrun simctl io booted screenshot <path>` - Capture clean screenshot
  - Captures framebuffer without simulator chrome/bezel
  - Options: `--type=png`, `--display=<index>`
- `xcrun simctl install <UDID> <path>` - Install app on simulator
- `xcrun simctl launch <UDID> <bundle-id>` - Launch app
- `xcrun simctl terminate <UDID> <bundle-id>` - Terminate app
- `xcrun simctl get_app_container <UDID> <bundle-id>` - Get app container path

**Primary Use Cases:**
- Clean screenshots for App Store or documentation
- Simulator lifecycle management
- App installation and launching
- Container access for debugging
- Bulk operations across multiple simulators

**Integration:**
- Native Xcode tool, always available
- Primary method for iOS Simulator screenshots
- Simulator management in CI/CD pipelines

**Related Skills:**
- [ios-simulator-screenshot.md](../../.claude/skills/ios-simulator-screenshot.md)

**Common Patterns:**
```bash
# List booted simulators
xcrun simctl list | grep Booted

# Clean screenshot capture
xcrun simctl io booted screenshot llmtemp/screenshots/clean.png

# Boot specific simulator
xcrun simctl boot D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75

# Install and launch app
xcrun simctl install booted /path/to/app.app
xcrun simctl launch booted com.example.app
```

**Comparison with AXe:**
| Feature | AXe | xcrun simctl |
|---------|-----|--------------|
| UI Interaction | ✅ Tap, type, gesture | ❌ No interaction |
| Screenshots | ❌ Not available | ✅ Clean framebuffer |
| Video Recording | ✅ Yes | ❌ No |
| Simulator Management | ⚠️ Limited | ✅ Full control |
| Installation | Homebrew | Built-in with Xcode |

**Notes:**
- `xcrun simctl` is the **primary method** for iOS Simulator screenshots in this project
- Captures clean framebuffer without simulator bezel (ideal for documentation)
- Fast, lightweight, and has no external dependencies

---

### xcodebuild
- **Purpose**: Build, test, and archive Xcode projects
- **Docs**: Built into Xcode, see [xcode.md](../xcode.md)
- **Installation**: Included with Xcode

**Common Commands (from CLAUDE.md):**
```bash
# Build project
xcodebuild -scheme VivaDicta -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  build | xcbeautify

# Run tests
xcodebuild -scheme VivaDicta -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test | xcbeautify

# Run single test
xcodebuild -scheme VivaDicta -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -only-testing:VivaDictaTests/TestClassName/testMethodName | xcbeautify
```

**Primary Use Cases:**
- Build iOS app for testing or release
- Run unit and UI tests
- Generate test reports
- CI/CD integration
- Archive builds for distribution

**Integration:**
- Core build tool for VivaDicta project
- Used with xcbeautify for formatted output
- Default simulator: iPhone 17 Pro (iOS 26.0)

---

### xcbeautify
- **Purpose**: Format xcodebuild output for better readability
- **Repository**: https://github.com/cpisciotta/xcbeautify
- **Installation**: Homebrew (`brew install xcbeautify`)

**Usage:**
```bash
xcodebuild [options] | xcbeautify
```

**Primary Use Cases:**
- Clean, readable build output
- Highlight errors and warnings
- Progress indicators during build
- Test result formatting

---

## Tool Integration Patterns

### Screenshot Workflow
```bash
# 1. Use AXe to navigate
axe tap -x 195 -y 400 --udid $UDID
axe gesture scroll-up --udid $UDID

# 2. Wait for animation to complete
sleep 0.5

# 3. Capture with xcrun simctl (primary method)
xcrun simctl io booted screenshot llmtemp/screenshots/screenshot.png
```

### Testing Workflow
```bash
# 1. Build the app
xcodebuild -scheme VivaDicta build | xcbeautify

# 2. Run tests
xcodebuild -scheme VivaDicta test | xcbeautify

# 3. Automate UI interactions with AXe if needed
axe tap -x 195 -y 400 --udid $UDID

# 4. Capture results with xcrun simctl
xcrun simctl io booted screenshot llmtemp/screenshots/test_result.png
```

## Configuration

### Default Simulator (VivaDicta Project)
- **Device**: iPhone 17 Pro
- **OS**: iOS 26.0
- **UDID**: D28078F6-0BE9-4EB8-BEBE-BF8EBEA5CA75

### Screenshot Directory
- **Location**: `llmtemp/screenshots/`
- **Git Status**: Ignored (safe for temporary files)
- **Format**: PNG (default), JPEG supported

## Adding New Tools

When adding a new CLI tool:
1. Add documentation to this directory
2. Update this README with tool details
3. Document common commands and patterns
4. Create skills if tool requires complex workflows
5. Note installation method and dependencies

## Resources

- [AXe GitHub Repository](https://github.com/cameroncooke/AXe)
- [Apple Developer Documentation - simctl](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)
- [Xcode Command Line Tools](https://developer.apple.com/xcode/resources/)
- [xcbeautify GitHub Repository](https://github.com/cpisciotta/xcbeautify)
