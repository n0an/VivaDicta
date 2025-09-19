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
   - Check project documentation (README, CLAUDE.md, docs/)
   - Identify which frameworks/libraries are available
   - Understand the current architecture
   - Find similar existing features to use as reference

4. **Ask Clarifying Questions** (if needed)
   - Request any missing requirements
   - Confirm assumptions about the implementation
   - Clarify priorities if multiple approaches exist

### Phase 2: PLAN (Design the Solution)
1. **Create a Todo List**
   - Use TodoWrite to create a comprehensive task list
   - Break down the implementation into logical steps
   - Order tasks by dependencies and priority
   - Include verification/testing tasks

2. **Design the Solution**
   - Outline the technical approach
   - Identify files that need to be created/modified
   - Plan the component/module structure
   - Consider edge cases and error handling
   - Plan for testing strategy

3. **Communicate the Plan**
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
   - Use build/lint/typecheck commands as specified in CLAUDE.md
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
3. Present findings and move to PLAN phase
4. Create detailed todo list and get user approval
5. Execute CODE phase systematically
6. Provide summary of completed work

## Example Usage

User: "Implement a new feature for exporting transcriptions to PDF format"

Assistant would:
- EXPLORE: Search for existing export functionality, PDF libraries, transcription models
- PLAN: Create todos for PDF generation, UI components, export logic, tests
- CODE: Implement each todo systematically with proper testing

Remember: For complex tasks, investing time in exploration and planning saves significant time during implementation and reduces errors.