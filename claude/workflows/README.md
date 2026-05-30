# Dynamic workflows

Deterministic multi-agent orchestration. A workflow is a small JavaScript script
that fans out **tens to hundreds of subagents** in the background, holds the loop
and intermediate results in script variables (not the chat context), and applies a
**quality pattern** — adversarial verification, judged synthesis, loop-until-dry —
so the result is more trustworthy than a single pass, not just bigger.

These are compass's, and they route stages to compass's own cost-tiered subagents
(security → `security-auditor` on opus, the rest → `code-reviewer`/`architect`),
so **cost follows risk** the same way the rest of the repo does.

| Command | Pattern | What it does |
|---|---|---|
| `/compass-review` | parallel dimensions → adversarial verify → synthesize | Reviews the branch diff on 5 dimensions at once; a skeptic refutes each finding before it's reported; returns one Blocking/Should-fix/Nit verdict. The everyday lever. |
| `/compass-audit` | multi-modal finders → loop-until-dry → 3-lens vote | Whole-codebase bug & security sweep. Six blind finders, repeated until two dry rounds; each fresh finding ships only if 2-of-3 lenses confirm it. The coverage lever. |
| `/compass-plan` | N angles → judge panel → grafted synthesis | Drafts a plan from MVP-first / risk-first / simplicity angles, scores them, and synthesizes one plan from the winner keeping the best ideas of the rest. The confidence lever. |

## Requirements (honest)

Dynamic workflows are a **research preview** and need **Claude Code v2.1.154+**
(`claude --version`). On Pro, enable them in `/config` → *Dynamic workflows*. If your
build doesn't have them, treat these as aspirational — the rest of compass is
unaffected. Off-switch: `disableWorkflows: true` in settings, or
`CLAUDE_CODE_DISABLE_WORKFLOWS=1`.

## Run them

After `make install` these are symlinked into `~/.claude/workflows/`, so they're
available as slash commands in **every** repo:

```text
/compass-review
/compass-audit             # audits the repo; pass a path to narrow it
/compass-plan add a token-bucket rate limiter to the login endpoint
```

A workflow run goes to the background; watch it with `/workflows` (arrow-keys to a
phase, Enter to drill in, `x` to stop, `s` to save your own). Subagents always run
in `acceptEdits` and inherit your tool allowlist — add any commands they need to
`permissions.allow` first so a long run doesn't stall on a prompt.

You don't have to install these to get workflows: in any session, just put the word
**workflow** in your prompt and Claude writes one for the task; `/effort ultracode`
makes it do that automatically for every substantive task. compass ships these three
because they're the ones worth running the same way every time — and because they're
readable, you can audit exactly what fans out before you trust it.

## Write your own

Each file is `export const meta = {…}` (name → the `/command`, description, `phases`)
followed by a body using `agent()`, `parallel()`, and `pipeline()`. Read
`compass-review.js` first — it's the canonical pattern (pipeline by default; a
barrier only when a stage genuinely needs all prior results at once). Validate the
shape with `scripts/check-workflows.sh` (also run in CI).
