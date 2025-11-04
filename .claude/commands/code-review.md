# code-review

You are given the following context:
$ARGUMENTS

<IMPORTANT>
DON'T CHANGE ANYTHING. JUST REVIEW THE CHANGES
</IMPORTANT>

## Task
Perform a comprehensive code review of the current changes (git diff) in the repository.

## Instructions

Use the `code-reviewer` agent to perform the review. The agent is specifically configured to:
- Review against VivaDicta project standards (CLAUDE.md)
- Verify Swift 6, SwiftUI, and SwiftData best practices
- Check architecture patterns (@Observable, TranscriptionService, etc.)
- Assess code quality, performance, security, and testing

Launch the agent with any additional context provided in $ARGUMENTS.

The `code-reviewer` agent will provide structured feedback including:
- Change summary
- Strengths and positive aspects
- Issues found (Critical/Important/Minor)
- Specific suggestions with code examples
- Overall assessment and merge readiness