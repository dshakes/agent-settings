---
description: Open a pull request with a description generated from the diff
argument-hint: "[optional PR title]"
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(gh pr create:*), Bash(git push:*)
---
Prepare and open a PR for the current branch.

Branch: !`git branch --show-current`
Commits not on the base: !`git log --oneline @{u}.. 2>/dev/null || git log --oneline -10`
Diff stat: !`git diff --stat $(git merge-base HEAD origin/main 2>/dev/null || echo HEAD~5)..HEAD`

1. If I'm on a protected branch (main/master), stop — I need a feature branch first.
2. Draft a PR title (use $ARGUMENTS if given) and a body with: **What** changed and
   **why**, a short **testing** section (what you ran), and any **risk/rollout**
   notes. Match the repo's PR style if there's a template.
3. Show me the title and body. **On my confirmation**, push the branch and run
   `gh pr create` with them. Never force-push.
