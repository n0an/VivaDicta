# code-review

You are given the following context:
$ARGUMENTS

## Task
Perform a comprehensive code review of the current changes (git diff) in the repository.

## Instructions

1. **Examine changes**: Run `git diff` and `git status` to understand what changed

2. **Review against project standards**:
   - Refer to `CLAUDE.md` for project-specific guidelines, architecture patterns, and best practices
   - Use `/docs/` directory references mentioned in CLAUDE.md for Swift/SwiftUI/SwiftData best practices
   - Pay special attention to the "Code Review Guidelines" section in CLAUDE.md

3. **Focus areas**:
   - **Code Quality**: Logic errors, edge cases, error handling
   - **Swift 6 Compliance**: Proper concurrency, @MainActor isolation
   - **Architecture**: Adherence to VivaDicta patterns (@Observable, SwiftData models, etc.)
   - **Performance**: State management optimization, memory usage
   - **Security**: API key handling, data validation
   - **Testing**: Coverage for new functionality

4. **Provide structured feedback**:

### 📊 Change Summary
Brief overview of what changed

### ✅ Positive Aspects
What's done well

### 🔍 Issues Found
- **🔴 Critical**: Must fix before merging
- **🟡 Important**: Should address
- **🔵 Minor**: Nice to have improvements

### 💡 Suggestions
Specific improvements with code examples

### ✨ Overall Assessment
Final verdict and merge readiness

## Important
Always cross-reference with CLAUDE.md for current project conventions and the `/docs/` directory for Apple framework best practices.