# AI PR Review + iOS Test Automation

This repository includes an automated AI-powered Pull Request review system with iOS test execution.

## How It Works

When a Pull Request is opened, updated, or reopened against the `main` branch:

1. **Code Review Phase**: AI analyzes the PR changes and generates a comprehensive code review
2. **iOS Test Phase**: Automatically runs the existing iOS test suite using xcodebuild
3. **Results**: Posts a combined comment with both code review findings and test results

## Workflow Overview

The automation runs on **macOS runners** (required for iOS development) with the following steps:

1. **Checkout code** with full git history
2. **Setup Node.js** for the AI review scripts
3. **Setup Xcode** with latest stable version
4. **Create & boot iOS Simulator** (iPhone 17 Pro)
5. **Run AI Agent** which performs:
   - Code review generation
   - iOS test execution
   - Results posting

## Configuration

### Required GitHub Secrets

Set these in your repository settings under `Settings > Secrets and variables > Actions`:

- `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` - For AI code review
- `LLM_PROVIDER` - Either `"openai"` or `"anthropic"` (optional, defaults to openai)

### Test Execution

The system runs iOS tests using:
```bash
xcodebuild test -scheme VivaDicta \
  -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0" | xcbeautify
```

## Project Structure

### AI Agent Files
- `.github/workflows/ai-agent.yml` - GitHub Actions workflow
- `scripts/ai-pr-review.ts` - Entry point script
- `lib/agents/flow-runner.ts` - Main orchestration logic
- `lib/agents/ios-test-runner.ts` - iOS test execution
- `lib/agents/code-review.ts` - AI code review generation
- `lib/agents/github-comments.ts` - PR comment management
- `lib/agents/pr-context.ts` - PR data collection
- `lib/agents/llm.ts` - AI provider integration

### Test Files
- `VivaDictaTests/VivaDictaTests.swift` - Main test file
- Uses Swift Testing framework

## Features

### Code Review
- AI-powered analysis of code changes
- File-by-file detailed review
- Overall suggestions and recommendations
- Intelligent context understanding

### iOS Test Automation
- Runs existing test suite automatically
- Parses test results and provides detailed reporting
- Shows test counts, duration, and failure details
- No test generation - only executes existing tests

### GitHub Integration
- Automatic PR comments with results
- Real-time updates during execution
- Clear success/failure indicators
- Preserves review history

## Simple Design

This implementation is intentionally simplified compared to the level-3-agent reference:
- **No test generation** - only runs existing tests
- **No iterative test fixing** - reports results as-is  
- **No gating logic** - always runs tests after review
- **Single workflow** - combines review and testing in one job

## Usage

Simply open a Pull Request against the `main` branch. The AI agent will automatically:
1. Post an initial "starting" comment
2. Generate and post a code review
3. Update the comment to show "running tests"
4. Post final results with both review and test outcomes

The entire process typically takes 2-5 minutes depending on code complexity and test suite size.