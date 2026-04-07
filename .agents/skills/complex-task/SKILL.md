---
name: complex-task
description: Systematic Explore-Plan-Code framework for tackling complex implementation tasks
---

# complex-task

You are given the following context:
$ARGUMENTS

## Framework: Explore → Plan → Code

You are about to work on a complex task. Follow this systematic approach to ensure thorough understanding and successful implementation:

### Phase 1: EXPLORE (Understand the Context)
1. **Analyze the Request**
   - Break down what the user is asking for
   - Identify key requirements and constraints
   - Note any ambiguities that need clarification

2. **Explore the Codebase**
   - Use Grep/Glob to find relevant files and patterns
   - Read existing implementations for context
   - Identify dependencies and related components
   - Check for existing tests or documentation
   - Look for coding patterns and conventions used in the project

3. **Research & Gather Information**
   - Check project documentation (README, AGENTS.md, documentation/)
   - Identify which frameworks/libraries are available
   - Understand the current architecture
   - Find similar existing features to use as reference

4. **Swift 6 Concurrency Analysis** (Critical for iOS/Swift projects)
   - Check if Swift 6 strict concurrency is enabled in the project
   - Identify @MainActor isolation requirements for UI code
   - Look for existing actor-based patterns (e.g., WhisperKit, Parakeet services)
   - Review async/await usage in similar components
   - Check for Sendable conformance requirements
   - Understand data race prevention patterns in the codebase
   - Note: SwiftUI Views are implicitly @MainActor in Swift 6

5. **Ask Clarifying Questions** (if needed)
   - Request any missing requirements
   - Confirm assumptions about the implementation
   - Clarify priorities if multiple approaches exist

### Phase 2: PLAN (Design the Solution)
1. **Review Project Documentation**
   - Check the `/documentation/` directory for relevant architecture docs
   - Review AGENTS.md for project conventions and best practices
   - Ensure alignment with existing patterns

2. **Create a Todo List**
   - Use TodoWrite to create a comprehensive task list
   - Break down the implementation into logical steps
   - Order tasks by dependencies and priority
   - Include verification/testing tasks
   - Save plan to some file

3. **Design the Solution**
   - Outline the technical approach
   - Identify files that need to be created/modified
   - Plan the component/module structure
   - Consider edge cases and error handling
   - Plan for testing strategy

4. **Communicate the Plan**
   - Present the plan to the user
   - Explain key design decisions
   - Get confirmation before proceeding with implementation

### Phase 3: CODE (Implement the Solution)
1. **Implement Step by Step**
   - Work through the todo list systematically
   - Mark todos as in_progress when starting
   - Mark todos as completed immediately when done
   - Follow existing code patterns and conventions
   - Write clean, maintainable code

2. **Test As You Go**
   - Run relevant tests after each significant change
   - Use build/lint/typecheck commands as specified in AGENTS.md
   - Verify the functionality works as expected
   - Handle any errors that arise

3. **Review & Polish**
   - Ensure all todos are completed
   - Run final build and test commands
   - Review code for consistency with project standards
   - Clean up any debugging code or comments

## Execution Instructions

1. Start by acknowledging the complex task
2. Enter EXPLORE phase - be thorough in understanding the context
   - Use TodoWrite to track exploration tasks if multiple areas need investigation
3. Present findings and move to PLAN phase
   - Always use TodoWrite to create comprehensive task list
4. Get user approval on the plan
5. Execute CODE phase systematically
   - Update todos to in_progress when starting each task
   - Mark todos as completed immediately after finishing each task
6. Provide summary of completed work

**Important**: Use TodoWrite proactively throughout ALL phases to maintain visibility of progress. Don't wait until the PLAN phase - start tracking tasks as soon as you begin exploring.

## iOS/Swift Specific Patterns

When working on iOS/Swift projects, follow these patterns from AGENTS.md:

### SwiftData Models
```swift
@Model
final class MyModel {
    // Use @Model, NOT Core Data NSManagedObject
    var property: String
    // Follow SwiftData patterns from documentation/swiftdata.md
}
```

### SwiftUI Views
```swift
struct MyView: View {
    @State private var data: String = ""  // Use @State/@Binding, NOT @StateObject
    // Views are implicitly @MainActor in Swift 6

    var body: some View {
        NavigationStack {  // Use NavigationStack, NOT NavigationView
            // Implementation
        }
        .foregroundStyle(.primary)  // Use foregroundStyle, NOT foregroundColor
    }
}
```

### State Management
- Use `@Observable` macro, NOT @ObservableObject/@Published
- Use `@State` with `onChange` for expensive operations instead of computed properties
- Extract reusable components for better organization

### Async/Await Patterns
```swift
// Prefer async/await over completion handlers
func fetchData() async throws -> Data {
    // Actor-based patterns for thread safety
    // SwiftUI Views are implicitly @MainActor in Swift 6
    // Explicit @MainActor needed only for:
    //   - ViewModels/ObservableObjects (if used)
    //   - Non-UI types that update UI state
    //   - Closures that update @State from background tasks
}
```

### Swift 6 Concurrency Checklist
- Enable strict concurrency checking in build settings
- All UI updates isolated to @MainActor
- Use actors for shared mutable state (e.g., WhisperContext)
- Mark types as Sendable when crossing concurrency boundaries
- Avoid completion handlers - use async/await
- Remember: SwiftUI Views are implicitly @MainActor
- Use `nonisolated` for non-UI async functions when appropriate

### Performance Optimization
- Use `@State` with `onChange` modifiers for expensive filtering
- Extract reusable UI components
- Actor-based patterns for thread-safe access to heavy resources

## Example Usage

### Example 1: iOS Feature Implementation
User: "Add a new settings screen for managing export preferences"

Assistant would:
- EXPLORE:
  - Search for existing Settings views and patterns
  - Check AppState for state management approach
  - Review `/documentation/` for relevant architecture docs
- PLAN:
  - Review existing @Observable patterns in codebase
  - Create todos: Settings model, SwiftUI view, AppState integration
  - Follow @Observable pattern for state management
- CODE:
  - Implement using NavigationStack and @State
  - Use SwiftData @Model for persistence
  - Follow async/await for any network calls

### Example 2: Transcription Service Integration
User: "Implement a new cloud transcription service"

Assistant would:
- EXPLORE:
  - Review TranscriptionService protocol
  - Check existing services (OpenAI, Groq, etc.)
  - Study CloudTranscriptionService patterns
- PLAN:
  - Review existing transcription service implementations for async patterns
  - Design actor-based service for thread safety
  - Plan error handling and retry logic
- CODE:
  - Implement TranscriptionService protocol
  - Use async/await, NOT completion handlers
  - Integrate with AppState using @Observable

Remember: For complex tasks, investing time in exploration and planning saves significant time during implementation and reduces errors.
