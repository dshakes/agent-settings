# Cost & model routing

The single biggest lever on agent cost is **which model does which job**. Token
counts dwarf per-token price differences, so routing the bulk (mechanical, parallel
work) to cheap models while keeping deep reasoning on Opus wins on both cost *and*
speed.

## The three tiers

| Tier | Model | Where it's set | Jobs |
|---|---|---|---|
| **Cheap** | Haiku 4.5 | `test-runner` subagent | run tests, parse failures, triage logs, mechanical edits, "find all callers" sweeps |
| **Standard** | Sonnet 4.6 | `code-reviewer`, `go-engineer`, `rust-engineer`, `docs-writer`, `k8s-operator` | most feature coding, refactors, reviews, docs |
| **Deep** | Opus 4.7 | driver session + `architect`, `security-auditor`, `debugger` | architecture, security, subtle debugging |

Change a subagent's tier by editing the `model:` line in its
`claude/agents/<name>.md`. Accepted values: a model ID
(`claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`) or `inherit`.

## How the savings actually happen
- **Delegation keeps the driver's context small.** A subagent reads 20 files and
  returns a 5-line conclusion; the expensive driver context never holds those 20
  files. Less context = fewer tokens per subsequent turn.
- **Cheap models do the volume.** Test runs and log triage are high-token,
  low-reasoning. On Haiku they're nearly free.
- **`/cost`** re-plans a task into a delegation table before you spend.

## Effort level
`effortLevel: "high"` in `settings.json` buys deeper reasoning per turn (worth it
on the Opus driver). Subagents on cheaper models implicitly cost less per turn;
you can also dial Codex reasoning per profile (`deep`/`standard`/`cheap`).

## Watching spend
The status line shows estimated session cost (`$x.xx`) and context size, so you
notice a runaway before it's expensive. `/cost` is the deliberate re-plan.

## Rules of thumb baked into `CLAUDE.md`
- Don't re-read a file you just edited.
- Don't re-run a search you already delegated.
- Prefer one well-scoped subagent over many main-thread file reads.
- Reserve Opus for where a wrong answer is expensive.
