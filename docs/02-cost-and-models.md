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

## Bring your own model — local LLMs & cost routers (Codex side)
The cheapest token is one you don't pay for. Codex talks to **any OpenAI-compatible endpoint**,
so a tier can run on a **local model** (free, private) or a **cost router**:

| Profile | Backend | Use |
|---|---|---|
| `codex --profile local` | **Ollama / LM Studio** (`localhost:11434/v1`) | grunt work on a free local model — zero API cost |
| `codex --profile router` | **OpenRouter** (one key → many models) | route to the cheapest *capable* model per task |

These ship **inert** in `codex/config.toml` (`[model_providers.ollama|openrouter]` + the
`local`/`router` profiles) — the default tiers are unchanged; opt in per command. Set
`OPENROUTER_API_KEY` for the router; pull a coding model (e.g. `ollama pull qwen2.5-coder`) for
local. Edit the example model names to ones you actually have.

**Honest limit:** this lever is **Codex-side**. Claude Code's core agent runs Claude (or Claude
via **Bedrock/Vertex** for enterprise: `CLAUDE_CODE_USE_BEDROCK` / `..._VERTEX`) — it does *not*
run arbitrary local/OpenRouter models. So the cross-tool play is: Claude Code for deep Claude
reasoning, a **local/router-backed Codex** for cheap high-volume work + the independent audit.
Cross-provider *smart routing* as a first-class compass layer is roadmapped (`docs/10-roadmap.md` §10).

## Watching spend (pre/post budgeting)
- **Live (interactive):** the status line shows estimated session cost (`$x.xx`) and context
  size, so you notice a runaway before it's expensive. `/cost` is the deliberate pre-plan.
- **Per-run budget cap:** every autonomous step is hard-capped — `--max-budget-usd` on each
  cloud workflow step and on each `orchestrate.sh` Claude step (`SDLC_BUDGET`/4 by default).
- **Pre-run estimate:** `orchestrate.sh` prints the per-step cap and total budget hint before
  it starts — you know the ceiling up front.
- **Post-run analysis:** when `jq` is present, `orchestrate.sh` captures each step's real cost
  (`claude -p --output-format json` → `total_cost_usd`) into `.sdlc/run-*/costs.tsv`, prints a
  per-step breakdown + total, and includes a **Spend** line in the PR body. (QA is free; the
  Codex audit isn't tallied.)

## Rules of thumb baked into `CLAUDE.md`
- Don't re-read a file you just edited.
- Don't re-run a search you already delegated.
- Prefer one well-scoped subagent over many main-thread file reads.
- Reserve Opus for where a wrong answer is expensive.
