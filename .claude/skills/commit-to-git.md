# Commit to Git

Use this skill when the user asks to commit changes to git, or when you've completed work and changes are ready to be committed.

## Related Skills

- This skill only covers committing - not pushing or creating PRs
- For push operations, always ask user for confirmation first per project guidelines

## Skill Flow

- Example queries:
  - "commit these changes"
  - "create a commit for this work"
  - "git commit this"
- Notes:
  - **ALWAYS ask "do we need to commit and push at the moment?" before executing any git commands**
  - Never include "Co-Authored-By: Claude" or any AI attribution
  - Follow the project's existing commit message style
  - Keep commit messages clean and attributed solely to the human author

### 1. Review Current State

Check what will be committed:

```bash
# See all changes
git status

# Review the actual diff
git diff

# Check recent commits for style reference
git log --oneline -10
```

### 2. Ask for User Confirmation

Before proceeding with commit:

> "Do we need to commit and push at the moment?"

Wait for user approval. If user says no, stop here.

### 3. Stage Changes

Add files to staging area:

```bash
# Add specific files
git add path/to/file1 path/to/file2

# Or add all changes (use with caution)
git add .
```

### 4. Create Commit

Use a heredoc for proper formatting:

```bash
git commit -m "$(cat <<'EOF'
Brief, descriptive commit message

Optional longer description if needed.
Can include multiple lines explaining the changes.
EOF
)"
```

**Commit message guidelines:**
- Use imperative mood ("Add feature" not "Added feature")
- Be concise but descriptive
- Reference issue numbers if relevant (e.g., "VIV-123")
- Follow existing project patterns from `git log`
- NO AI attribution or co-authoring

**Example commit messages from this project:**
- "Cleanup Parakeet transcription service"
- "Code refactoring"
- "Refactor transcribeSpeechTask"
- "VIV-31 Cleanup .foregroundColor"

### 5. Verify Commit

Check that commit was created successfully:

```bash
git status
git log -1
```

### 6. Ask About Push

After successful commit:

> "The changes have been committed. Do you want to push them to the remote repository?"

Wait for user approval before executing any push commands.

## Common Scenarios

### Scenario A: Partial Commit

If only some changed files should be committed:

```bash
# Add only specific files
git add path/to/file1.swift path/to/file2.md

# Commit those files only
git commit -m "Descriptive message"
```

### Scenario B: Amend Previous Commit

If user wants to amend (use with caution - check authorship first):

```bash
# Check authorship of last commit
git log -1 --format='%an %ae'

# Only amend if it's the user's commit
git commit --amend -m "Updated message"
```

**⚠️ Never amend other developers' commits**

### Scenario C: Unstaged Changes Remain

If some files should stay unstaged:

```bash
# This is intentional - only commit what was staged
git status  # Show what remains unstaged
```

Explain to user that unstaged changes remain for future commits.

## Error Handling

### Pre-commit Hook Failures

If commit fails due to pre-commit hooks:

1. Review the hook output
2. Fix any issues identified by hooks
3. Re-stage fixed files
4. Retry commit once

### Merge Conflicts

If there are merge conflicts:

```bash
git status  # See conflicted files
```

Stop and ask user to resolve conflicts manually before committing.

### Nothing to Commit

If `git status` shows no changes:

Inform user: "There are no changes to commit. The working directory is clean."
