# pr

You are given the following context:
$ARGUMENTS

## Task: Create a GitHub Pull Request

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

If no arguments are provided, create a PR with auto-generated title and description based on the commit history.

Use appropriate flags like `--draft` if the PR is work in progress.