# Skill Library

## How to Use Skills

Scan this file for relevant skills based on the given task.

**General guidelines:**

- Skills are "recipes" with examples of how similar problems were solved - adapt them to the current context
- When a task matches multiple skills, synthesize the approaches rather than following one skill blindly
- If you see a better approach than what's in a skill, use your judgment
- Skills are guides, not rules - prioritize what makes sense for this specific situation
- Cross-reference between skills when they share patterns

## Skill List

- [`add-new-screen.md`](./add-new-screen.md): Add a new screen (View) to the VivaDicta iOS app
- [`axe-simulator-control.md`](./axe-simulator-control.md): Automate iOS Simulator with AXe terminal tool for taps, gestures, text input, and video recording
- [`commit-to-git.md`](./commit-to-git.md): Commit changes to git following project guidelines
- [`ios-log-capture.md`](./ios-log-capture.md): Capture console logs from iOS apps in Simulator or physical devices using native iOS logging tools
- [`ios-simulator-screenshot.md`](./ios-simulator-screenshot.md): Capture screenshots from iOS Simulator using native xcrun simctl command
- [`xcodebuild-testing.md`](./xcodebuild-testing.md): Run unit tests and UI tests using xcodebuild command-line tool

## Skill Directory

### Add New Screen

For adding a new screen (SwiftUI View) to the VivaDicta iOS app.

- Skill file: [`add-new-screen.md`](./add-new-screen.md)
- Related queries:
  - "add a new screen for viewing statistics"
  - "create a new view for user profile"
  - "I need a new screen in the settings tab"
  - "add a detail view for this data"

### AXe Simulator Control

For automating iOS Simulator interactions using the AXe terminal tool.

- Skill file: [`axe-simulator-control.md`](./axe-simulator-control.md)
- Related queries:
  - "tap at coordinates in the simulator"
  - "type text into the simulator"
  - "press the home button"
  - "record simulator video"
  - "perform a scroll gesture"
  - "list available simulators"
  - "swipe from edge in simulator"

### Commit to Git

For committing changes to the git repository following project-specific guidelines.

- Skill file: [`commit-to-git.md`](./commit-to-git.md)
- Related queries:
  - "commit these changes"
  - "create a commit for this work"
  - "git commit this"
  - "save these changes to git"

### iOS Log Capture

For capturing console logs from iOS apps running in Simulator or on physical devices using native iOS logging tools and slash commands.

- Skill file: [`ios-log-capture.md`](./ios-log-capture.md)
- Related queries:
  - "capture logs from the simulator"
  - "start logging the app in simulator"
  - "get console output from the running app"
  - "capture logs from physical iPhone"
  - "debug app crash with logs"
  - "monitor app output during testing"
  - "debug this issue by looking at logs"
- Related commands:
  - `/start-logs` - Start simulator log capture
  - `/stop-logs` - Stop simulator log capture and view summary
  - `/start-logs-device` - Launch app on device with print logging (main app process only, real-time)
  - `/stop-logs-device` - Stop device log capture
  - `/start-logs-device-structured` - Record timestamp for device logs (captures all processes including extensions — use when debugging interaction between main app and keyboard/widget/share extensions)
  - `/stop-logs-device-structured` - Collect structured device logs

### iOS Simulator Screenshot

For capturing screenshots from the iOS Simulator using native xcrun simctl command.

- Skill file: [`ios-simulator-screenshot.md`](./ios-simulator-screenshot.md)
- Related queries:
  - "take a screenshot of the simulator"
  - "capture the current simulator screen"
  - "screenshot the iOS simulator"
  - "save simulator screen to file"
  - "capture and analyze simulator screenshot"

### Xcodebuild Testing

For running unit tests and UI tests using xcodebuild command-line tool.

- Skill file: [`xcodebuild-testing.md`](./xcodebuild-testing.md)
- Related queries:
  - "run all tests"
  - "run tests for the app"
  - "run a specific test"
  - "test this feature"
  - "run failing tests"
  - "execute unit tests"
  - "run test class"
