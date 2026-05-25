---
description: Review the current diff with a coordinated agent TEAM (parallel reviewers that talk to each other) instead of sequential subagents. Experimental — needs CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1.
argument-hint: "[optional PR number or git range, default: working changes]"
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(gh pr view:*), Task
---

Review ${ARGUMENTS:+$ARGUMENTS }with a coordinated **agent team** (parallel, not sequential).

> **Experimental.** Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (set in this repo's
> `settings.json`). Agent teams have rough edges (no teammate resumption, task-status lag).
> Prefer this for interactive review; the headless pipeline stays sequential.

Spin up a small team and have them **message each other**, not just report in isolation:

1. **Lead (you)** — gather the diff (`git diff` / `gh pr view`), create a shared task list,
   and spawn three teammates with disjoint mandates:
   - **Correctness** — logic, edge cases, error paths, conventions (model: sonnet)
   - **Security** — authz, injection, secrets, tenancy, trust boundaries (model: opus)
   - **Tests/QA** — coverage gaps, missing regression tests, flake risk (model: haiku/sonnet)
2. **Cross-talk** — teammates `SendMessage` when findings interact (e.g., Security flags an
   input that Correctness approved; Tests notes the fix lacks coverage). Resolve conflicts
   between them, don't just concatenate.
3. **Lead synthesis** — produce ONE reconciled report grouped **Blocking / Should-fix / Nit**,
   noting where reviewers agreed vs. disagreed and how you resolved it.

Do **not** edit files or merge — this is review only. The human still owns the merge gate.
