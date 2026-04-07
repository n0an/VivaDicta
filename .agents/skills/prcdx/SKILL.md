---
name: prcdx
description: Create a GitHub Pull Request in Codex with optional Claude review request and standard GitHub polling
disable-model-invocation: true
---

# prcdx

You are given the following context:
$ARGUMENTS

## Task: Create a GitHub Pull Request in Codex

Based on the provided context, create a pull request following these steps:

1. First, check the current git status and uncommitted changes.
2. If there are uncommitted changes, ask if they should be committed first.
3. Ensure the current branch is not `main` or `master`.
4. Push the current branch to remote if needed.
5. Create the pull request using `gh pr create` with:
   - A clear, descriptive title
   - A comprehensive description including:
     - Summary of changes
     - Testing performed
     - Any breaking changes or notes
6. Return the PR URL when complete.

## IMPORTANT: Final Summary

**ALWAYS** end your response with a clear summary that includes:

- What was done (branch created, commits made, PR opened, review requested, etc.)
- **The PR URL** (for example: `PR #123: https://github.com/owner/repo/pull/123`)
- Whether Claude review was requested
- Whether the PR is ready for review

Format the PR link prominently so it's easy to find.

If no arguments are provided, create a PR with an auto-generated title and description based on the current branch and commit history.

Use `--draft` if the work is clearly in progress.

## Codex Review Flow

After the PR is created, follow this review workflow unless the user explicitly says not to:

1. Post a comment requesting Claude review:
   ```bash
   gh pr comment <PR_NUMBER> --body "@claude please review this PR"
   ```
2. Poll GitHub using standard CLI or API commands, not Claude Code slash commands.
3. Check both issue comments and PR reviews every 2 minutes for a bounded period.
4. Stop polling once a real review arrives, not just an "in progress" placeholder.
5. Show the review to the user and ask what they want to do next.

## Suggested Polling Approach

Use normal GitHub commands such as:

```bash
gh pr view <PR_NUMBER> --json comments,reviews,url
```

or:

```bash
gh api repos/<owner>/<repo>/issues/<PR_NUMBER>/comments
gh api repos/<owner>/<repo>/pulls/<PR_NUMBER>/reviews
```

When polling:

- Record a baseline timestamp immediately before or after posting the `@claude` comment
- Only treat newer comments or reviews as candidate review results
- Ignore empty bodies and obvious "review in progress" placeholders
- Stop after a reasonable bounded wait if no review arrives, and tell the user review was requested but not yet returned

## Handling Review Feedback

- **Real critical bugs** (regressions, data loss, crashes, security issues): fix them immediately without asking.
- **Everything else** (style, theoretical issues, nice-to-haves, non-critical improvements): present to the user with your assessment and ask before fixing.
