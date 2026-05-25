---
description: Draft a lightweight spec / intent doc for a feature — the ground truth the build and review verify AGAINST. Use before non-trivial work; skip for one-liners. Writes a short, committed spec to specs/.
argument-hint: "[feature/task description, or an issue number]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(git log:*), Bash(gh issue view:*)
---

Draft a **spec / intent** for: ${ARGUMENTS:-the task we're about to do}.

The point: give the loop a **ground truth**. Tests prove the code *works*; the spec proves it
does *what was asked*. The Builder implements against it; the Reviewer and QA verify against
its acceptance criteria. Keep it **short and honest** — a spec that rots is worse than none.

## Do
1. Read the relevant code, `CLAUDE.md`, and any linked issue first (don't spec in a vacuum).
2. Write `specs/<kebab-slug>.md` with exactly these sections, tight:
   - **Intent** — 1–3 sentences: what outcome, for whom, why now.
   - **Acceptance criteria** — a numbered, *verifiable* checklist (each item testable;
     prefer "given/when/then" where it helps). This is the contract.
   - **Non-goals** — what this explicitly does NOT do (prevents scope creep).
   - **Constraints / invariants** — perf, security/tenancy, back-compat, dependencies.
   - **Verification plan** — how each acceptance criterion will be checked (test, manual, metric).
   - **Open questions** — anything needing a human decision before/while building.
3. If a load-bearing invariant changes, say "needs ADR" and stop short (use `/adr`).
4. Keep it under ~1 page. Commit it (`git add specs/… && git commit`). Report the path.

## Then (spec-driven loop)
Hand the spec to implementation: `~/compass/sdlc/orchestrate.sh "<task>"` with
`SDLC_SPEC=specs/<slug>.md` set — the Planner plans to the spec, the Builder implements it,
and the Reviewer is told to **verify the diff against the acceptance criteria** (flag any
unmet or out-of-scope). The human approves the *spec* (intent), not just the diff.

> Lightweight by design. For a typo or one-liner, skip the spec — this is for features where
> "did we build the right thing?" is a real question.
