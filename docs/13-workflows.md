# Dynamic workflows

> **The newest harness primitive, adopted day one.** Dynamic workflows are a Claude
> Code research preview (requires **v2.1.154+**; on Pro, enable in `/config` →
> *Dynamic workflows*). If your build doesn't have them, the rest of compass is
> unaffected — these are additive and clearly gated.

A **workflow** is a small JavaScript script the Claude Code runtime executes in the
background. Unlike a subagent or a skill — where *Claude* decides turn-by-turn what
runs next and every result lands in the chat context — a workflow moves the plan
**into code**: the loop, the branching, and the intermediate results live in script
variables, so your context holds only the final answer, and it can fan out **tens to
hundreds of subagents** (16 concurrent, 1,000 per run) that the session never has to
hold in memory.

That shift is what lets a workflow apply a **quality pattern**, not just run more
agents: independent agents can adversarially review each other's findings before
anything is reported, or draft a plan from several angles and weigh them — so the
result is more *trustworthy*, not merely bigger.

## Why compass ships its own

The everyday review/audit/plan loops are exactly the cases worth running the **same
way every time**, and they benefit most from parallelism + verification. compass's
three workflows also do something a generic one can't: each routes its stages to
compass's **own cost-tiered subagents** (`agentType`), so the security dimension
runs on the opus `security-auditor` while the rest run on the sonnet `code-reviewer`
— **cost follows risk**, the same principle as the rest of the repo.

| Command | Pattern | The lever |
|---|---|---|
| `/compass-review` | parallel dimensions → adversarial verify → synthesize | **Everyday.** Reviews the branch diff on five dimensions (correctness, security, performance, tests, conventions) concurrently; a skeptic tries to *refute* each finding before it's reported; returns one Blocking/Should-fix/Nit verdict. Faster and less noisy than a single-pass review. |
| `/compass-audit` | multi-modal finders → loop-until-dry → 3-lens vote | **Coverage.** Six blind finders hunt different failure classes (authz, injection, error-handling, concurrency, resource leaks, secrets), repeated until two dry rounds; each fresh finding ships only if **2 of 3** perspective-diverse lenses confirm it. Scope with `args.path`. |
| `/compass-plan` | N angles → judge panel → grafted synthesis | **Confidence.** Drafts a plan MVP-first / risk-first / simplicity-first, scores each on one rubric, then synthesizes a single plan from the winner while grafting the best ideas of the runners-up. For ambiguous changes where the approach isn't obvious. |

## Run them

After `make install` (or `./quickstart.sh`) the scripts are symlinked into
`~/.claude/workflows/`, so they're available as slash commands in **every** repo:

```text
/compass-review
/compass-audit                                   # whole repo; pass a path to narrow
/compass-plan add a token-bucket rate limiter to the login endpoint
```

A run goes to the background; watch it with **`/workflows`** (arrow-keys to a phase,
Enter to drill into an agent, `x` to stop, `p` to pause/resume, `s` to save your own).
The subagents always run in `acceptEdits` and **inherit your tool allowlist**, so add
any commands they need to `permissions.allow` first or a long run may stall on a
prompt.

You don't have to install these to get workflows at all: put the word **`workflow`**
in any prompt and Claude writes one for the task; `/effort ultracode` makes it do that
automatically for every substantive task in the session. compass ships these three
because they're the ones worth codifying — and because they're **readable**, you can
audit exactly what fans out before you trust it.

## Cost & control

A workflow spawns many agents, so one run uses meaningfully more tokens than the same
task in conversation — it buys *thoroughness*, spend accordingly. Every agent uses
your **session model** unless a stage routes elsewhere (compass's do, via `agentType`).
Check `/model` before a large `/compass-audit`. Stop any run from `/workflows` without
losing completed work.

Off-switch (any of): toggle *Dynamic workflows* off in `/config`; set
`"disableWorkflows": true` in `~/.claude/settings.json`; or `CLAUDE_CODE_DISABLE_WORKFLOWS=1`.

## Write your own

Each file in `claude/workflows/` is `export const meta = { name, description, phases }`
(the `name` becomes the `/command`) followed by a body using `agent()`, `parallel()`,
and `pipeline()`. Read [`compass-review.js`](../claude/workflows/compass-review.js)
first — it's the canonical shape:

- **`pipeline(items, …stages)`** is the default: each item flows through every stage
  independently, no barrier — item B's findings verify while item A is still being
  reviewed.
- **`parallel(thunks)`** is a barrier — use it only when a stage genuinely needs *all*
  prior results at once (e.g. dedup across every finding before verifying).
- **`agent(prompt, { schema, agentType, label, phase })`** spawns one subagent; with a
  `schema` it returns a validated object. Route to a compass subagent with `agentType`.

Validate the shape (and JS syntax, when `node` is present) with
[`scripts/check-workflows.sh`](../scripts/check-workflows.sh) — it runs in CI, so a
malformed workflow fails the build like everything else here.

## Honest limits

- **Research preview.** The feature, the save path (`/workflows` → `s`), and the exact
  runtime are still moving. compass pins the scripts and validates their shape; treat
  anything your build doesn't support as aspirational, per the repo's
  [grounded-over-impressive](00-philosophy.md) rule.
- **Plugin install doesn't carry workflows.** They ship via the full install
  (symlinked `~/.claude/workflows/`), not the `core` plugin — plugins bundle
  agents/commands/skills/hooks/MCP, not workflows (yet).
- **The human still merges.** A workflow reviews, audits, or plans; it doesn't push or
  deploy. Same boundary as the rest of compass.
