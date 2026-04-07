---
name: xcodebuild-testing
description: Run unit tests, UI tests, or specific test cases for VivaDicta using xcodebuild command-line tool
---

# Xcodebuild Testing

Use this skill when you need to run unit tests, UI tests, or specific test cases for the VivaDicta iOS app using xcodebuild command-line tool.

## Related Skills

- See [`ios-log-capture`](../ios-log-capture/SKILL.md) for capturing logs during test execution
- See [`axe-simulator-control`](../axe-simulator-control/SKILL.md) for automating simulator interactions during UI tests
- See [`screenshot`](../screenshot/SKILL.md) for capturing screenshots during test failures

## Skill Flow

- Example queries:
  - "run all tests"
  - "run tests for the app"
  - "run a specific test"
  - "run only failing tests"
  - "run tests and show me the results"
- Notes:
  - Uses native `xcodebuild test` command (not XcodeBuildMCP)
  - Output piped through `xcsift` (or `xcbeautify`) for readable formatting
  - Default simulator: iPhone 17 Pro Max, OS=26.4
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
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test 2>&1 | xcsift

# Alternative: Save test results to file
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test 2>&1 | tee test_results.txt 2>&1 | xcsift
```

**Available parameters:**
- `-scheme`: Xcode scheme to build and test (VivaDicta)
- `-configuration`: Build configuration (Debug or Release)
- `-workspace`: Path to workspace file
- `-destination`: Simulator or device to run tests on
- `test`: The xcodebuild action to run tests

**Notes:**
- `xcsift` formats the output for better readability (alternatively `xcbeautify`)
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
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -dry-run 2>&1 | grep "Test Case" 2>&1 | xcsift

# Or search in test files
find . -name "*Tests.swift" -exec grep -H "func test" {} \;
```

### 3B. Run Specific Test

```bash
# Run a single test method
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -only-testing:VivaDictaTests/TranscriptionManagerTests/testWhisperKitTranscription 2>&1 | xcsift

# Run multiple specific tests
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test \
  -only-testing:VivaDictaTests/TranscriptionManagerTests/testWhisperKitTranscription \
  -only-testing:VivaDictaTests/TranscriptionManagerTests/testParakeetTranscription 2>&1 | xcsift
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
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -only-testing:VivaDictaTests/TranscriptionManagerTests 2>&1 | xcsift

# Run multiple test classes
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test \
  -only-testing:VivaDictaTests/TranscriptionManagerTests \
  -only-testing:VivaDictaTests/AIServiceTests 2>&1 | xcsift
```

**Notes:**
- Omit the method name to run all tests in the class
- Format: `-only-testing:<Target>/<Class>`
- Useful for feature-specific test runs

## Path D: Run with Log Capture

### 2D. Start Log Capture Session

Start log capture using the `start-logs` skill. See [`ios-log-capture`](../ios-log-capture/SKILL.md) for the full logging workflow.

This will:
- Automatically detect the booted simulator
- Start capturing VivaDicta logs in the background
- Save logs to `logs/sim-YYYYMMDD-HHMMSS.log`
- The app continues running without restart

### 3D. Run Tests

```bash
# Run tests while logs are being captured
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test 2>&1 | xcsift
```

### 4D. Stop Log Capture and Analyze

Stop capture with the `stop-logs` skill.

Useful follow-up filters:
- `stop-logs errors`
- `stop-logs warnings`

Manual analysis remains the same:

```bash
grep -i "error\\|fail\\|crash" logs/sim-*.log
grep "test" logs/sim-*.log
```

## Common Workflows

### Quick Test Run During Development

```bash
# Run specific test you're working on
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -only-testing:VivaDictaTests/MyFeatureTests/testNewFeature 2>&1 | xcsift
```

### Test Run with Results Saved

```bash
# Run all tests and save results
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test 2>&1 | tee logs/test_results_$(date +%Y%m%d_%H%M%S).txt 2>&1 | xcsift

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
  test 2>&1 | xcsift
```

### Run Only Failed Tests from Previous Run

```bash
# After a test run fails, rerun only failed tests
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -only-testing:VivaDictaTests/FailedTestClass/testThatFailed 2>&1 | xcsift
```

### Parallel Test Execution

```bash
# Enable parallel testing (default)
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -parallel-testing-enabled YES 2>&1 | xcsift

# Disable parallel testing (for debugging race conditions)
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -parallel-testing-enabled NO 2>&1 | xcsift
```

### Test Run with Code Coverage

```bash
# Run tests with code coverage enabled
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -enableCodeCoverage YES 2>&1 | xcsift

# View coverage report location
# DerivedData/<project>/Logs/Test/*.xcresult
```

### Debug Test Failures with Screenshots

```bash
# 1. Run tests and note which test fails
xcodebuild -scheme VivaDicta \
  -configuration Debug \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
  test -only-testing:VivaDictaTests/UITests/testLoginFlow 2>&1 | xcsift

# 2. If test fails, capture screenshot using xcrun simctl
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

**xcsift not found:**
- Install xcsift: `brew install xcsift` (or use `xcbeautify` as alternative: `brew install xcbeautify`)
- Or run without it (remove `2>&1 | xcsift` from command)

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

1. **Use xcsift for readable output:**
   - Always pipe through `xcsift` for formatted output (project standard)
   - Install with: `brew install xcsift` (or `xcbeautify` as alternative)

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
   - Stick to project default: iPhone 17 Pro Max, OS=26.4
   - Document in AGENTS.md if changed
   - Match CI/CD simulator configuration

6. **Clean build when tests behave unexpectedly:**
   ```bash
   xcodebuild clean -scheme VivaDicta \
     -workspace ./VivaDicta.xcodeproj/project.xcworkspace
   ```

7. **Check exit codes in scripts:**
   ```bash
   xcodebuild ... test 2>&1 | xcsift
   if [ $? -ne 0 ]; then
     echo "Tests failed!"
     exit 1
   fi
   ```

8. **Organize test output:**
   ```bash
   mkdir -p logs/test-results
   xcodebuild ... test 2>&1 | tee logs/test-results/run_$(date +%Y%m%d_%H%M%S).txt 2>&1 | xcsift
   ```

9. **Use test plans for different configurations:**
   - Create test plans in Xcode for different scenarios
   - Reference with `-testPlan <name>` flag

10. **Monitor test execution time:**
    - Use `-result-bundle-path` to save detailed results
    - Analyze `.xcresult` bundles for performance insights
