---
description: Review the current diff for correctness, security, and conventions
argument-hint: "[optional path or git range, default: working changes]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Task
---
Review the following changes${ARGUMENTS:+ ($ARGUMENTS)}.

Status:
!`git status --short`

Diff:
!`git diff HEAD -- $ARGUMENTS`

Delegate to the **code-reviewer** subagent. If the diff touches auth, crypto,
tenant isolation, secrets, or untrusted input, also run the **security-auditor**
subagent in parallel. Consolidate into one list ordered Blocking → Should-fix →
Nit, each as `path:line — issue — fix`. Do not change any code unless I ask.
