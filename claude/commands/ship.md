---
description: Pre-ship pipeline — test, review, then prepare a clean commit
argument-hint: "[optional commit message]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Task
---
Run the pre-ship pipeline on the current working changes. Do **not** push or
create a PR — stop at a ready-to-commit state and wait for me.

Changes:
!`git status --short`

Steps:
1. **Test** — delegate to the **test-runner** subagent. If anything fails, stop and
   report; don't proceed.
2. **Review** — delegate to the **code-reviewer** subagent (and **security-auditor**
   if the diff touches auth/crypto/tenancy/secrets/untrusted input). Fix anything
   **Blocking**; list Should-fix/Nit for me to decide.
3. **Verify** — re-run the relevant tests if you changed anything in step 2.
4. **Prepare commit** — propose a commit message following this repo's recent
   style (`git log --oneline -10`). Use $ARGUMENTS as the message if I gave one.
   Stage the right files and show me the final `git diff --cached` summary and the
   message. **Do not commit until I confirm.**

Report each step's outcome as you go.
