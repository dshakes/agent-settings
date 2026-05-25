---
description: Run the headless SDLC pipeline (plan→build→review→audit→security→QA→PR) on a task
argument-hint: "<task description>"
allowed-tools: Bash(*), Read, Edit, Write, Grep, Glob, Task
---
Drive the autonomous SDLC pipeline for: **$ARGUMENTS**

Prefer the governed orchestrator so every agent runs with its scoped tools, budget
caps, and ordered handoff, ending at a PR for human merge (never auto-merge):

```
~/compass/sdlc/orchestrate.sh "$ARGUMENTS"
```

If the orchestrator isn't installed, run the same sequence yourself, delegating each
stage to the matching subagent and stopping at an opened PR:
1. **Plan** — architect subagent → a concrete plan.
2. **Build** — go-engineer/rust-engineer (or general) implements on a `sdlc/…` branch.
3. **Review** — code-reviewer subagent on the diff.
4. **Audit** — note: an independent Codex pass (`codex exec --sandbox read-only`) for a
   cross-tool second opinion.
5. **Security** — security-auditor subagent.
6. **QA** — test-runner subagent.
7. **Gate** — open the PR with a summary of all stages. **Do not merge or deploy** —
   that's the human gate. Report the PR URL.
