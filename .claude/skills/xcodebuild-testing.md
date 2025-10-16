# Xcodebuild Testing

Use this skill when you need to run unit tests, UI tests, or specific test cases for the VivaDicta iOS app using xcodebuild command-line tool.

## Related Skills

- See [`ios-log-capture.md`](./ios-log-capture.md) for capturing logs during test execution
- See [`axe-simulator-control.md`](./axe-simulator-control.md) for automating simulator interactions during UI tests
- See [`ios-simulator-screenshot.md`](./ios-simulator-screenshot.md) for capturing screenshots during test failures

## Skill Flow

- Example queries:
  - "run all tests"
  - "run tests for the app"
  - "run a specific test"
  - "run only failing tests"
  - "run tests and show me the results"
- Notes:
  - Uses native `xcodebuild test` command (not XcodeBuildMCP)
  - Output piped through `xcbeautify` for readable formatting
  - Default simulator: iPhone 17 Pro, OS=26.0
  - Tests run in Debug configuration
  - Workspace path: `./VivaDicta.xcodeproj/project.xcworkspace`
  - Scheme: `VivaDicta`

### 1. Determine Test Scope

**Run All Tests** if:
- Want to run entire test suite
- Verifying overall app health
- Running tests in CI/CD

→ Continue with **Path A: Run All Tests** (step 2A)

**Run Specific Test** if:
- Debugging a specific failing test
- Testing a specific feature or component
- Want faster feedback on targeted functionality

→ Continue with **Path B: Run Specific Test** (steps 2B-3B)

**Run Test Class** if:
- Want to run all tests in a specific test class
- Testing a specific module or feature area
- Iterating on a group of related tests

→ Continue with **Path C: Run Test Class** (steps 2C-3C)

**Run with Log Capture** if:
- Need detailed logs from test execution
- Debugging test failures
- Want to analyze app behavior during tests

→ Continue with **Path D: Run with Log Capture** (steps 2D-4D)

## Path A: Run All Tests

### 2A. Run Full Test Suite

```bash
# Run all tests in the VivaDicta scheme
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test | xcbeautify

# Alternative: Save test results to file
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test 2>&1 | tee test_results.txt | xcbeautify
```

**Available parameters:**
- `-scheme`: Xcode scheme to build and test (VivaDicta)
- `-configuration`: Build configuration (Debug or Release)
- `-workspace`: Path to workspace file
- `-destination`: Simulator or device to run tests on
- `test`: The xcodebuild action to run tests

**Notes:**
- `xcbeautify` formats the output for better readability
- `tee` allows saving output to file while still displaying it
- Simulator will be booted automatically if not already running
- Tests run in parallel by default (can be disabled with `-parallel-testing-enabled NO`)

## Path B: Run Specific Test

### 2B. Identify Test Target

You need three pieces of information:
1. **Test target name** - Usually `VivaDictaTests` or `VivaDictaUITests`
2. **Test class name** - The Swift class containing the test
3. **Test method name** - The specific test method

```bash
# Example test identifier format:
# VivaDictaTests/TranscriptionManagerTests/testWhisperKitTranscription
# ^target         ^class                  ^method
```

**Finding test names:**
```bash
# List all test classes and methods
xcodebuild -scheme VivaDicta \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -dry-run 2>&1 | grep "Test Case" | xcbeautify

# Or search in test files
find . -name "*Tests.swift" -exec grep -H "func test" {} \;
```

### 3B. Run Specific Test

```bash
# Run a single test method
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -only-testing:VivaDictaTests/TranscriptionManagerTests/testWhisperKitTranscription | xcbeautify

# Run multiple specific tests
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test \
  -only-testing:VivaDictaTests/TranscriptionManagerTests/testWhisperKitTranscription \
  -only-testing:VivaDictaTests/TranscriptionManagerTests/testParakeetTranscription | xcbeautify
```

**Parameters:**
- `-only-testing:<Target>/<Class>/<Method>` - Specifies exact test to run
- Can use multiple `-only-testing` flags to run specific tests

**Notes:**
- Much faster than running all tests
- Useful for TDD (Test-Driven Development) workflows
- Can specify target/class without method to run all tests in that class

## Path C: Run Test Class

### 2C. Identify Test Class

```bash
# Find test classes in the project
find . -name "*Tests.swift" | sed 's/.*\///' | sed 's/.swift//'

# Example output:
# TranscriptionManagerTests
# WhisperKitServiceTests
# AIServiceTests
```

### 3C. Run All Tests in Class

```bash
# Run all tests in a specific test class
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -only-testing:VivaDictaTests/TranscriptionManagerTests | xcbeautify

# Run multiple test classes
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test \
  -only-testing:VivaDictaTests/TranscriptionManagerTests \
  -only-testing:VivaDictaTests/AIServiceTests | xcbeautify
```

**Notes:**
- Omit the method name to run all tests in the class
- Format: `-only-testing:<Target>/<Class>`
- Useful for feature-specific test runs

## Path D: Run with Log Capture

### 2D. Start Log Capture Session

First, get the simulator UUID and start log capture:

```bash
# Get booted simulator UUID
SIMULATOR_UUID=$(axe list-simulators | grep Booted | head -1 | sed -E 's/.*- ([A-F0-9-]+).*/\1/')

# Start log capture (see ios-log-capture.md for details)
mcpli start-sim-log-cap \
  --simulatorUuid "$SIMULATOR_UUID" \
  --bundleId "com.antonnovoselov.VivaDicta" \
  --captureConsole true \
  -- npx -y xcodebuildmcp@latest
```

Save the returned session ID for later.

### 3D. Run Tests

```bash
# Run tests while logs are being captured
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test | xcbeautify
```

### 4D. Stop Log Capture and Analyze

```bash
# Stop capture and save logs
mcpli stop-sim-log-cap \
  --logSessionId "<session-id>" \
  -- npx -y xcodebuildmcp@latest > logs/test_run_$(date +%Y%m%d_%H%M%S).txt

# Analyze logs for errors
grep -i "error\|fail\|crash" logs/test_run_*.txt
```

## Common Workflows

### Quick Test Run During Development

```bash
# Run specific test you're working on
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -only-testing:VivaDictaTests/MyFeatureTests/testNewFeature | xcbeautify
```

### Test Run with Results Saved

```bash
# Run all tests and save results
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test 2>&1 | tee logs/test_results_$(date +%Y%m%d_%H%M%S).txt | xcbeautify

# Check exit code
echo "Test exit code: $?"
```

### Run Tests on Different Simulator

```bash
# List available simulators
xcrun simctl list devices available

# Run on specific simulator
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  test | xcbeautify
```

### Run Only Failed Tests from Previous Run

```bash
# After a test run fails, rerun only failed tests
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -only-testing:VivaDictaTests/FailedTestClass/testThatFailed | xcbeautify
```

### Parallel Test Execution

```bash
# Enable parallel testing (default)
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -parallel-testing-enabled YES | xcbeautify

# Disable parallel testing (for debugging race conditions)
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -parallel-testing-enabled NO | xcbeautify
```

### Test Run with Code Coverage

```bash
# Run tests with code coverage enabled
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -enableCodeCoverage YES | xcbeautify

# View coverage report location
# DerivedData/<project>/Logs/Test/*.xcresult
```

### Debug Test Failures with Screenshots

```bash
# 1. Run tests and note which test fails
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  test -only-testing:VivaDictaTests/UITests/testLoginFlow | xcbeautify

# 2. If test fails, capture screenshot (use Peekaboo or xcrun simctl)
xcrun simctl io booted screenshot logs/test_failure_$(date +%Y%m%d_%H%M%S).png
```

## Troubleshooting

**"Testing failed" with no clear error:**
- Check if simulator is booted: `xcrun simctl list | grep Booted`
- Verify scheme exists: `xcodebuild -list`
- Clean build folder: `xcodebuild clean` then retry
- Check for compilation errors in the test target

**"Unable to boot device" error:**
- Simulator may be stuck: `xcrun simctl shutdown all` then retry
- Check simulator exists: `xcrun simctl list devices`
- Free up disk space if needed
- Restart Simulator.app

**Tests hang or timeout:**
- Check for UI tests waiting for elements that don't appear
- Disable parallel testing: `-parallel-testing-enabled NO`
- Increase test timeout in scheme settings (Xcode UI)
- Check for deadlocks in test code

**"Test target not found" error:**
- Verify test target name is correct (case-sensitive)
- Check test target is included in scheme: `xcodebuild -list`
- Ensure test files are members of test target in Xcode

**xcbeautify not found:**
- Install xcbeautify: `brew install xcbeautify`
- Or run without it (remove `| xcbeautify` from command)

**Specific test not found:**
- Verify test method starts with `test` prefix
- Check test class inherits from XCTestCase
- Ensure test method is `func test...()` not private
- Try `-dry-run` to see all available tests

**Simulator wrong OS version:**
- List available OS versions: `xcrun simctl list runtimes`
- Download runtime in Xcode: Settings → Platforms
- Adjust destination to match available runtime

## Best Practices

1. **Use xcbeautify for readable output:**
   - Always pipe through `xcbeautify` for formatted output
   - Install with: `brew install xcbeautify`

2. **Run specific tests during development:**
   - Faster feedback loop
   - Use `-only-testing` for TDD workflow
   - Run full suite before committing

3. **Save test results for analysis:**
   - Use `tee` to save output while viewing it
   - Store in `logs/` directory (gitignored)
   - Include timestamps in filenames

4. **Combine with log capture for debugging:**
   - Start log capture before running tests
   - Capture both test output and app logs
   - Cross-reference timestamps

5. **Use consistent simulator:**
   - Stick to project default: iPhone 17 Pro, OS=26.0
   - Document in CLAUDE.md if changed
   - Match CI/CD simulator configuration

6. **Clean build when tests behave unexpectedly:**
   ```bash
   xcodebuild clean -scheme VivaDicta \
     -workspace ./VivaDicta.xcodeproj/project.xcworkspace
   ```

7. **Check exit codes in scripts:**
   ```bash
   xcodebuild ... test | xcbeautify
   if [ $? -ne 0 ]; then
     echo "Tests failed!"
     exit 1
   fi
   ```

8. **Organize test output:**
   ```bash
   mkdir -p logs/test-results
   xcodebuild ... test 2>&1 | tee logs/test-results/run_$(date +%Y%m%d_%H%M%S).txt | xcbeautify
   ```

9. **Use test plans for different configurations:**
   - Create test plans in Xcode for different scenarios
   - Reference with `-testPlan <name>` flag

10. **Monitor test execution time:**
    - Use `-result-bundle-path` to save detailed results
    - Analyze `.xcresult` bundles for performance insights
