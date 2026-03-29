---
name: git-worktree
description: Manage git worktrees for working on multiple branches simultaneously
disable-model-invocation: true
---

# git-worktree

You are given the following context:
$ARGUMENTS

## Task: Manage Git Worktrees

Git worktrees allow you to have multiple working trees attached to the same repository, enabling work on multiple branches simultaneously without switching.

### Common Operations

Based on the context provided, perform the appropriate worktree operation:

1. **List existing worktrees**
   ```bash
   git worktree list
   ```

2. **Create a new worktree**
   - For existing branch:
     ```bash
     git worktree add <path> <branch-name>
     ```
   - For new branch:
     ```bash
     git worktree add -b <new-branch> <path> <base-branch>
     ```

3. **Remove a worktree**
   ```bash
   git worktree remove <worktree-path>
   ```

4. **Prune stale worktrees**
   ```bash
   git worktree prune
   ```

### Workflow

1. **Assess the request**: Determine what worktree operation is needed
2. **Check current state**: List existing worktrees to understand the current setup
3. **Perform the operation**: Execute the appropriate git worktree command
4. **Verify**: Confirm the operation succeeded

### Best Practices

- **Naming convention**: Use descriptive paths that match branch names (e.g., `../feature-xyz` for branch `feature-xyz`)
- **Cleanup**: Remove worktrees when no longer needed to avoid clutter
- **Location**: Create worktrees outside the main repository directory (typically in sibling directories)
- **Branch management**: Each worktree should work on a different branch to avoid conflicts

### Examples

**Example 1: Create worktree for bug fix**
```bash
# Check existing worktrees
git worktree list

# Create new worktree for bug fix
git worktree add -b fix-memory-leak ../fix-memory-leak main

# Navigate to new worktree
cd ../fix-memory-leak
```

**Example 2: Create worktree for existing PR branch**
```bash
# Fetch latest changes
git fetch origin

# Create worktree for existing remote branch
git worktree add ../pr-123 origin/feature-branch

# Navigate to worktree
cd ../pr-123
```

**Example 3: Clean up finished work**
```bash
# List all worktrees
git worktree list

# Remove specific worktree
git worktree remove ../old-feature

# Prune any stale worktree information
git worktree prune
```

### When to Use Worktrees

- Working on multiple features/fixes simultaneously
- Reviewing PRs while keeping main work intact
- Testing changes in isolation
- Comparing different branches side-by-side
- Building/testing different versions concurrently

### Important Notes

- Each worktree has its own working directory and index
- All worktrees share the same repository database (.git)
- Cannot check out the same branch in multiple worktrees
- Worktrees are local only - they don't affect remote repository
- Use `git worktree lock` to prevent accidental removal of important worktrees
