---
name: pr
description: Create a GitHub Pull Request in Claude Code with Claude and Codex review requests and built-in polling workflow
disable-model-invocation: true
---

# pr

You are given the following context:
$ARGUMENTS

## Task: Create a GitHub Pull Request in Claude Code

This skill is the Claude Code-specific PR workflow. In Codex, use `$prcdx` instead.

Based on the provided context, create a pull request following these steps:

1. First, check the current git status and uncommitted changes
2. If there are uncommitted changes, ask if they should be committed first
3. Ensure the current branch is not main/master
4. Push the current branch to remote if needed
5. Create the pull request using `gh pr create` with:
   - A clear, descriptive title
   - A comprehensive description including:
     - Summary of changes
     - Testing performed
     - Any breaking changes or notes
6. Return the PR URL when complete

## IMPORTANT: Final Summary
**ALWAYS** end your response with a clear summary that includes:
- What was done (branch created, commits made, etc.)
- **The PR URL** (e.g., "PR #123: https://github.com/owner/repo/pull/123")
- Whether Claude review was requested
- Whether Codex review was requested
- The PR is ready for review

Format the PR link prominently so it's easy to find.

If no arguments are provided, create a PR with auto-generated title and description based on the commit history.

Use appropriate flags like `--draft` if the PR is work in progress.

## Post-PR: Request Review and Poll

After the PR is created, **always** do the following (skip only if the user explicitly says not to):

1. **Request reviews** by posting two comments on the PR:
   ```
   gh pr comment <PR_NUMBER> --body "@claude please review this PR"
   gh pr comment <PR_NUMBER> --body "@codex please review this PR"
   ```
2. **Start polling** for Claude and Codex review using `/loop 2m` to check PR comments, PR reviews, and inline review comments every 2 minutes:
   ```
   gh pr view <PR_NUMBER> --json comments,reviews,url
   gh api repos/<owner>/<repo>/issues/<PR_NUMBER>/comments
   gh api repos/<owner>/<repo>/pulls/<PR_NUMBER>/comments
   ```
3. **Do not stop polling** just because Claude replied first. Codex review usually takes longer.
4. **Keep polling** until you see a real Codex comment or review, not just "in progress" status, or until a reasonable bounded wait expires.
5. **Show the returned review feedback** to the user and ask "WDYT?" to discuss the findings before acting on them. If Claude replied but Codex has not yet replied, say that Codex review is still pending and keep polling until the bounded wait is reached.

## IMPORTANT: Review Inspection Hygiene

When checking review feedback, do **not** rely only on top-level PR reviews or summary comments.

- Always inspect **inline review comments / file-level threads** too.
- A generic top-level review body can still coexist with actionable inline comments.
- Inline comments may be attached to an older reviewed commit on the same branch and still be worth evaluating.
- Before dismissing a review as empty or boilerplate, check:
  - issue comments
  - PR reviews
  - pull request review comments / inline comments

Suggested extra check:

```bash
gh api repos/<owner>/<repo>/pulls/<PR_NUMBER>/comments
```

## Handling Review Feedback

- **Real critical bugs** (regressions, data loss, crashes, security issues): fix them immediately without asking.
- **Everything else** (style, theoretical issues, nice-to-haves, non-critical improvements): present to the user with your assessment and ask before fixing.

## Merge Requests

If the user explicitly says `merge`, do not wait for CI to finish.

- Merge the PR immediately using a regular merge commit.
- Do not block on pending checks unless the user explicitly asks to wait.
- If you see ongoing GitHub Actions build jobs for that PR or branch, submit a cancel request after merging instead of leaving them running.
- Do not wait for GitHub to confirm the cancellation. One cancel request is enough unless the user explicitly asks you to verify.
- Right after the merge, switch the local repository back to `main`.

## Post-Merge: Update What's New

After the PR is merged, update the running What's New file in the Obsidian vault:
- **File**: `Projects/VivaDicta/what's new/whats-new-running.md` in the vault at `/Users/antonnovoselov/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain Vault/`
- **Skip** if the PR is a one-liner simple fix, bug fix, refactor, or minor cleanup that users wouldn't notice.
- **Add** a concise, user-facing bullet point when the PR introduces a new feature or notable improvement. Write it from the user's perspective (what they can now do), not technical details. This file feeds into App Store Connect "What's New" release notes.
