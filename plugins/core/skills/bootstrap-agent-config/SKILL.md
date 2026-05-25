---
name: bootstrap-agent-config
description: Generate a high-quality project CLAUDE.md and AGENTS.md by inspecting the current repository. Use when a repo has no agent config, when onboarding a new project, or when the user asks to "set up Claude/Codex for this repo" or "write a CLAUDE.md". Detects languages, build/test commands, and structure, then drafts config grounded in what's actually there.
argument-hint: "[optional path, default: current repo]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Bootstrap agent config for a repository

Produce a `CLAUDE.md` and a symlinked/parallel `AGENTS.md` that are *grounded in
the real repo*, not generic boilerplate. A good config is the single highest-ROI
thing for agent productivity in a codebase — it pays for itself on the first task.

## Steps

1. **Detect the stack.** Run the helper to get a fast inventory:
   ```
   bash "${CLAUDE_SKILL_DIR}/detect-stack.sh" .
   ```
   It reports languages, package managers, build/test/lint commands, monorepo
   layout, and whether ADRs/CI exist.

2. **Verify, don't trust.** Confirm the detected build/test commands actually exist
   (read the Makefile / package.json / justfile). Read 2–3 representative source
   files to learn the real conventions (error handling, test style, naming).

3. **Find the invariants.** The most valuable part of a `CLAUDE.md` is the
   *load-bearing rules* — the things that cause incidents if violated. Look for
   them in: existing ADRs, `ARCHITECTURE.md`, `SECURITY.md`, README "gotchas", and
   patterns the code enforces (e.g. tenant scoping, a trust boundary, a generated
   file you must not hand-edit). Ask the user if the architecture isn't legible.

4. **Draft `CLAUDE.md`** using the structure in
   `${CLAUDE_SKILL_DIR}/../../../templates/CLAUDE.md.tmpl` as a skeleton. Fill every
   placeholder with real, verified content. Sections that matter most:
   - One-sentence "what this is"
   - Languages and *exact* build/test/lint commands (copy-pasteable)
   - Repo layout (only the parts an agent needs)
   - **Load-bearing invariants** — the "what NOT to do" list
   - How to run/verify locally
   Cut anything you can't ground in the actual repo. Short and true beats long and
   aspirational.

5. **Make `AGENTS.md` track it.** Most non-Claude tools (Codex, etc.) read
   `AGENTS.md`. Either symlink it (`ln -s CLAUDE.md AGENTS.md`) so there's one
   source of truth, or write a thin `AGENTS.md` that says "see CLAUDE.md". Prefer
   the symlink unless the repo already has a divergent `AGENTS.md`.

6. **Report** the files written and the top 3 invariants you encoded, so the user
   can correct anything you inferred.

## Quality bar
- Every command in the file runs. Every path exists. Every invariant is real.
- No "best practices" filler that isn't specific to this repo.
- If you had to guess at an invariant, mark it `(verify)` so the user checks it.
