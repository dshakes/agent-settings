<div align="center">

# 🧭 compass

**One configuration that makes Claude Code and Codex behave like your best engineer — by default, in every repo.**

[![ci](https://github.com/dshakes/compass/actions/workflows/ci.yml/badge.svg)](https://github.com/dshakes/compass/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/dshakes/compass?color=8A63D2)](https://github.com/dshakes/compass/releases)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-8A63D2.svg)](docs/05-plugin.md)
[![AGENTS.md](https://img.shields.io/badge/AGENTS.md-compatible-2ea44f.svg)](https://agents.md/)
[![status: alpha](https://img.shields.io/badge/status-alpha-orange.svg)](#status)

</div>

<p align="center">
  <img src="demo/preview.gif" alt="compass terminal demo: guardrail blocks rm -rf / and allows rm -rf ./build; the live status line (Claude Opus 4.7 · lantern · 42k ctx · $0.37); the autonomous PR loop — review · security · tests · Codex audit → BLOCKING → Builder fixes → CLEAN → you merge (humans own merge & deploy); the 9-subagent crew + 11 commands; and one-command install" width="900">
</p>

<sub>📐 <a href="assets/hero.svg">Architecture diagram</a> · re-render this demo with <code>make demo</code> (<a href="https://github.com/charmbracelet/vhs">vhs</a>)</sub>

> **No magic, no fabricated "secret configs."** Every piece is a *documented* Claude Code / Codex feature, assembled with care and cited where it matters. Read any file before you trust it — that's the point of shipping it as source.

> **🆕 Closed-loop autonomous PRs (alpha).** Open a PR and the agents review, security-check, test, and cross-audit it — then **auto-fix their own Blocking findings on the branch and re-review until clean**. You still merge. → [Autonomous SDLC](#autonomous-sdlc)

---

## Get started

**Full setup — one paste, every repo, fully reversible:**

```bash
git clone https://github.com/dshakes/compass ~/compass && cd ~/compass && make install && make doctor
```

**Zero-config — paste inside Claude Code (no terminal):**

```text
/plugin marketplace add dshakes/compass
/plugin install core@compass
```

**New to this?** → **[Using compass](docs/11-using-compass.md)** explains every piece in plain language — from your first session to the full autonomous loop — with the daily workflow and how to stay cheap and fast. Across many repos at once: `make apply-many DIRS="~/code/*"`.

> No `curl \| sh`. You clone it and read before you run — that's the point (compass *blocks* `curl\|sh` in your own work, too). Uninstall is one command: `make uninstall`.

### What you get, day one
- **Both tools, one config.** Claude Code **and** Codex behave like a senior engineer in *every* repo — understand first, stay in scope, verify before "done."
- **It stops the disasters.** Hard-blocks `rm -rf /`, secret writes, force-push to `main`; auto-formats every edit — silently.
- **It costs less.** Grunt work goes to cheap models, Opus is saved for the hard calls, and the status line shows live `$` spend.
- **It can run your PRs.** An optional autonomous loop reviews, security-checks, tests, cross-audits, and **auto-fixes its own findings** — you keep the merge.
- **As little or as much as you want.** The core is the manual + guardrails + subagents. The autonomous loop, scheduled agents, cross-tool (Gemini/Cursor/Windsurf) support, and local/router cost-routing are all **opt-in** — nothing you don't switch on ever runs.

---

## Contents

- [Get started](#get-started)
- [Quickstart](#quickstart)
- [Why compass](#why-compass)
- [See it work](#see-it-work)
- [How it fits together](#how-it-fits-together)
- [What's inside](#whats-inside)
- [The hooks](#the-hooks)
- [Cost model](#cost-model)
- [MCP servers](#mcp-servers)
- [Language servers (LSP)](#language-servers-lsp)
- [New or existing repos](#new-or-existing-repos)
- [Team rollout](#team-rollout)
- [Autonomous SDLC](#autonomous-sdlc)
- [Cross-tool: one source](#cross-tool-one-source)
- [Grounded in published practice](#grounded-in-published-practice)
- [Customizing](#customizing)
- [Safety and honesty](#safety-and-honesty)
- [Status](#status)
- [Docs](#docs)

---

## Quickstart

Pick **one** path — running both double-fires the hooks.

| Your situation | Path |
|---|---|
| Just me, my machine, every repo | **A · Full setup** |
| A team, or I don't want to touch my global config | **B · Plugin only** |

**A · Full setup** (recommended) — manual + permissions + statusline + hooks + subagents + MCP, global to every repo:

```bash
git clone https://github.com/dshakes/compass ~/compass && cd ~/compass
make dry-run     # preview every change
make install     # symlink into ~/.claude + ~/.codex (backs up first)
make doctor      # validate everything
```

**B · Plugin only** (zero-config, team-friendly) — the machinery, but *not* memory/permissions:

```bash
/plugin marketplace add dshakes/compass
/plugin install core@compass
```

**Across many repos at once:** `make apply-many DIRS="~/code/*"` (or `--git-only`). Then `make doctor` to validate.

→ **New here? Read [Using compass](docs/11-using-compass.md)** — install paths, the pieces (plugins vs skills vs hooks), the daily workflow, and how to stay cheap + fast. · [What each method can and can't ship](docs/05-plugin.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## Why compass

Everyone has the same models. The edge is the **configuration around them** — and most people rebuild it from scratch in every repo. compass ships it once:

- **It knows how to act** — one tight manual loads every session: understand first, stay in scope, verify before "done."
- **It stops the disaster** — hard-blocks `rm -rf /`, secret writes, `curl\|sh`, force-push to `main`; waves `rm -rf ./build` straight through.
- **It cleans up silently** — every file it edits is auto-formatted.
- **It costs less** — grunt work goes to Haiku/Sonnet; Opus is saved for the hard calls; the status line shows live `$` spend.
- **It brings a crew** — 9 specialists and 8 commands (`/ship` `/review` `/tdd` …), each on the right model.

<div align="right"><a href="#contents">↑ top</a></div>

---

## See it work

A normal session, after `make install` — nothing extra to invoke:

1. **You open any repo and start Claude.** The operating manual, your guardrails, the 9 subagents and 8 commands are already loaded. The status line shows the model, branch, and live `$` spend.
2. **You ask for a change.** Claude reads the relevant code first, states a 2–4 line plan, then implements — delegating the test run to a cheap Haiku subagent and saving Opus for the hard reasoning.
3. **It tries something dangerous.** `rm -rf $HOME`, a secret write, a force-push to `main` → **blocked** by the guardrail hook before it runs. `rm -rf ./build` sails through.
4. **Every file it touches is auto-formatted** (gofmt/ruff/prettier/…) — no "fix lint" round-trips.
5. **You run `/ship`.** It tests, runs a fresh-context reviewer, and prepares a clean commit. You stay the merge gate.
6. **You raise the PR.** Now the [Autonomous SDLC](#autonomous-sdlc) takes over: review, security, tests, and a cross-tool Codex audit run on the PR — and if the reviewer finds a Blocking issue, the Builder **fixes it on the branch and re-review until green**. You click merge.

> No new vocabulary to learn — it's the same Claude Code / Codex you already use, with a senior engineer's defaults switched on.

<div align="right"><a href="#contents">↑ top</a></div>

---

## How it fits together

One repo is the source of truth; `make install` **symlinks** it into your tools, so editing the repo edits your live config — and `git pull` updates everything. The same manual (via the `AGENTS.md` standard) reaches every major agent.

```mermaid
flowchart LR
  repo["compass repo<br/>one source of truth<br/>(CLAUDE.md ≙ AGENTS.md)"]
  repo -->|"make install"| claude["Claude Code<br/>~/.claude"]
  repo -->|"make install"| codex["Codex<br/>~/.codex"]
  repo -->|"install.sh --gemini"| gemini["Gemini CLI<br/>~/.gemini"]
  repo -. "per-repo AGENTS.md<br/>(Linux Foundation standard)" .-> ides["Cursor · Windsurf<br/>Copilot · Amp · Devin"]

  claude --> bundle["manual · guardrail + format hooks<br/>9 cost-tiered subagents · commands<br/>status line · MCP (context7/fetch/git)"]
  codex --> tiers["tiers: deep / standard / cheap<br/>+ local (Ollama) · router (OpenRouter)"]

  claude --> loop["autonomous PR loop<br/>review ⇄ fix · Codex cross-audit · human merge"]
  codex --> loop
```

<div align="right"><a href="#contents">↑ top</a></div>

---

## What's inside

| Area | What you get | Lives in |
|---|---|---|
| **Operating manual** | `CLAUDE.md` (≙ `AGENTS.md`), loaded every session | `claude/CLAUDE.md` |
| **Guardrail + quality hooks** | protect-paths · format-on-edit · inject-context · notify | `claude/hooks/` |
| **Specialist subagents** (9) | cost-tiered across Haiku / Sonnet / Opus | `claude/agents/` |
| **Workflow commands** (8) | `/ship` `/review` `/tdd` `/pr` `/adr` `/triage` `/scaffold` `/cost` | `claude/commands/` |
| **Skill** | bootstrap a grounded project `CLAUDE.md` | `claude/skills/` |
| **Status line** | model · dir · git · context · `$cost` | `claude/statusline.sh` |
| **Codex parity** | `AGENTS.md` + cost profiles | `codex/` |
| **MCP (single source)** | context7 · fetch · git | `mcp/servers.json` |
| **Plugins + marketplace** | `core`, `core-lsp` | `plugins/`, `.claude-plugin/` |

<details>
<summary><strong>Repo layout →</strong></summary>

```
compass/
├── claude/                  # → symlinked into ~/.claude
│   ├── settings.json        # model, permissions, hooks, statusline, env
│   ├── CLAUDE.md            # global operating manual
│   ├── statusline.sh        # model · dir · git · context · $cost
│   ├── output-styles/       # "Concise" terse tone
│   ├── agents/  commands/  skills/  hooks/
├── codex/                   # → symlinked/merged into ~/.codex (config.toml + AGENTS.md)
├── mcp/servers.json         # single-source MCP manifest → both tools
├── plugins/                 # core, core-lsp (self-contained)
├── .claude-plugin/          # marketplace.json
├── templates/  scripts/  docs/  demo/
├── install.sh  Makefile
```

</details>

→ [Architecture](docs/01-architecture.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## The hooks

Balanced posture: stop accidents, stay invisible otherwise. Dependency-light (jq → python3 → grep) and they **never fail a session**.

| Hook | Event | What it does |
|---|---|---|
| `protect-paths` | PreToolUse | **Blocks** secret writes, `rm -rf /` `~` `$HOME`, fork bombs, `curl\|sh`, force-push/hard-reset to `main`/`prod` — allows real subpaths. |
| `format-on-edit` | PostToolUse | Formats the edited file (gofmt, rustfmt, prettier/biome, ruff, shfmt, terraform, buf). |
| `inject-context` | SessionStart | Hands the agent branch, dirty state, recent commits up front. |
| `notify` | Stop / Notification | Desktop notification when a turn finishes or needs input (macOS/Linux). |

<div align="right"><a href="#contents">↑ top</a></div>

---

## Cost model

The driver runs **Opus 4.7 / high effort**; the savings come from **delegation**.

| Tier | Model | Used by | For |
|---|---|---|---|
| Cheap | Haiku 4.5 | `test-runner` | test runs, log triage, mechanical sweeps |
| Standard | Sonnet 4.6 | `code-reviewer`, `go/rust-engineer`, `docs-writer`, `k8s-operator` | most coding & review |
| Deep | Opus 4.7 | `architect`, `security-auditor`, `debugger`, driver | architecture, security, subtle bugs |

`/cost` re-plans any task to the cheapest-correct mix. → [Cost & models](docs/02-cost-and-models.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## MCP servers

One manifest ([`mcp/servers.json`](mcp/servers.json)) registers servers in **both** tools, skipping anything that would duplicate your existing Codex plugins.

```bash
make mcp          # register in Claude + Codex
claude mcp list   # verify health
```

- **Auto (secret-free):** `context7` (live library docs) · `fetch` (URL → markdown) · `git` (structured git).
- **Opt-in:** `github` (OAuth) · `postgres` (read-only, project-scoped — pre-wired for lantern, gated on `LANTERN_DATABASE_URL`).

→ [MCP guide](docs/04-mcp.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## Language servers (LSP)

An **opt-in** companion plugin gives Claude background **diagnostics + navigation** (zero context cost) for Go, Rust, TypeScript, Python:

```bash
/plugin install core-lsp@compass   # needs gopls / rust-analyzer / typescript-language-server / pyright on PATH
```

Separate because it needs the language-server binaries. Codex has no native LSP, so this one is Claude-only. → [LSP guide](docs/06-lsp.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## New or existing repos

After `make install`, the manual + hooks + subagents + MCP apply to **every** repo automatically. For committed, per-repo context:

```bash
make new-repo DIR=/path/to/repo            # existing repo: starter CLAUDE.md + AGENTS.md symlink
make new-repo DIR=/path/to/repo TEAM=1     # + pin core@compass for the whole team
make new-repo DIR=./brand-new TEAM=1       # new repo: git init + files + pinned settings
```

Then run Claude's `/init` or the `bootstrap-agent-config` skill to fill `CLAUDE.md` from the actual code. Tip: add `newrepo(){ ~/compass/scripts/new-repo.sh "$@"; }` to your shell. → [Defaults guide](docs/08-defaults.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## Team rollout

Commit a project `.claude/settings.json` so everyone who opens the repo gets the machinery, pinned to a tag for stability:

```jsonc
{
  "extraKnownMarketplaces": {
    "compass": { "source": { "source": "github", "repo": "dshakes/compass", "ref": "v0.7.0" } }
  },
  "enabledPlugins": { "core@compass": true }
}
```

A teammate is prompted to trust the repo, then it auto-enables. Anyone who already has it globally opts out per-repo in a gitignored `.claude/settings.local.json` (`{"enabledPlugins":{"core@compass":false}}`) to avoid double-firing hooks. **Live in the lantern repo.** → [Plugin guide](docs/05-plugin.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## Autonomous SDLC

A pipeline of **named, governed agents** — Planner · Builder · Reviewer · **Auditor (Codex)** · Security · QA · Releaser — that plan, build, review, cross-audit, security-check, and test your changes, while **humans keep the merge and deploy gates**.

```mermaid
flowchart TD
  pr["You open / push a PR"] --> onpush
  subgraph onpush["Runs automatically on the PR"]
    rev["Reviewer · Claude"]
    sec["Security · Claude opus"]
    qa["QA · runs tests"]
    aud["Auditor · Codex"]
  end
  onpush --> verdict{"Reviewer<br/>verdict"}
  verdict -->|CLEAN| green["checks green<br/>label: reviewed-clean"]
  verdict -->|BLOCKING| needsfix["label: agent:needs-fix"]
  needsfix --> builder["Builder fixes on the PR branch<br/>+ pushes via SDLC_BOT_TOKEN"]
  builder -->|"re-triggers the checks"| onpush
  builder -.->|"round cap, default 3"| human["label: sdlc:needs-human"]
  green --> gate["Human merge gate<br/>1 code-owner approval"]
  gate --> ship["You merge and deploy"]
```

**The loop, in words:** open a PR → Reviewer (Claude) + Security (Claude opus) + Auditor (Codex) + QA all fire automatically. If the Reviewer finds Blocking issues it labels `agent:needs-fix`, which triggers the **Builder** to fix the code on the PR's own branch and push — which re-runs the Reviewer. This repeats until clean or the round cap (`SDLC_MAX_FIX_ROUNDS`, default 3), then `sdlc:needs-human` is applied. Required status checks (`review` + `qa`) gate the merge; **humans merge and deploy**.

The loop auto-chains only with **`SDLC_BOT_TOKEN`** (a fine-grained PAT: Contents+PRs write). Without it, review and one fix still run but the loop won't continue — GitHub blocks workflow-to-workflow recursion with the default token.

```bash
# Headless, task-ordered (opens a PR, never merges):
~/compass/sdlc/orchestrate.sh "Add rate limiting to the login endpoint"

# GitHub-native closed loop (8 workflows, Reviewer ⇄ Builder):
export CLAUDE_CODE_OAUTH_TOKEN=…   # from `claude setup-token` — subscription, no API credits
export OPENAI_API_KEY=…            # Codex cloud audit
export SDLC_BOT_TOKEN=…            # fine-grained PAT — required for the loop to chain
~/compass/sdlc/setup.sh --all      # labels + workflows + CODEOWNERS + commit/push + secrets + branch protection

# …or KEYLESS — claude -p / codex exec on a self-hosted runner (SDLC_BOT_TOKEN still needed for chaining):
~/compass/sdlc/setup.sh --self-hosted --commit --protect   # see docs/09 + sdlc/selfhosted/README.md
```

**Which way to run it?**

| Model | Runs on | Auth | Manage a box? | API credits? |
|---|---|---|---|---|
| **A · Hosted + subscription token** *(simplest)* | GitHub's runners | `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`) | No | **No** |
| **B · Self-hosted, keyless** | your runner (VM/laptop) | logged-in `claude -p` | Yes | No |
| **C · Hosted + API key** | GitHub's runners | `ANTHROPIC_API_KEY` | No | Yes (pay-per-use) |
| **Local · no cloud** | your machine | your CLI login | No | No |

All four keep humans on merge & deploy. **A** is the easiest start. *(Validated end-to-end on a live repo — see [`sdlc/SMOKETEST.md`](sdlc/SMOKETEST.md).)*

Roster + tags + gates: [`sdlc/agents.registry.md`](sdlc/agents.registry.md). Full design, loop diagram, `SDLC_BOT_TOKEN` setup, required-status-check gate, security posture, and troubleshooting: [`docs/09-sdlc.md`](docs/09-sdlc.md).

<div align="right"><a href="#contents">↑ top</a></div>

---

## Cross-tool: one source

`AGENTS.md` — the open standard (now under the Linux Foundation's Agentic AI Foundation) read by **Codex, Cursor, Windsurf, Copilot, Amp, Devin** — is a **symlink to `CLAUDE.md`**, globally and per-repo. Edit the manual once; every agent reads the same instructions, no drift. **Gemini CLI** too: `./install.sh --gemini` feeds it the same manual. So your operating manual + conventions are **LLM/IDE-agnostic** — switch or mix vendors without rewriting config. → [Every agent, one source](docs/12-every-agent.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## Grounded in published practice

The defaults adopt **cited, verifiable** guidance — not invented ones:

- Anthropic — [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)
- The [agents.md](https://agents.md/) standard
- Andrej Karpathy's public principles (vibe-coding, "tight leash")
- Garry Tan's [`gstack`](https://github.com/garrytan/gstack)

The full mapping — and an honest note on what we did **not** fabricate — is in [`docs/07-practices.md`](docs/07-practices.md).

<div align="right"><a href="#contents">↑ top</a></div>

---

## Customizing

A starting point, not scripture — fork it. The global `CLAUDE.md` has a clearly-marked stack section you can delete if you're not polyglot AI-infra. Drop your own agents/commands/skills in as plain markdown; they're picked up automatically. → [Customize guide](docs/03-customize.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## Safety and honesty

- The installer **backs up** anything it replaces to `~/.claude/backups/` and is idempotent; `make uninstall` removes only what it created.
- Symlink install means `git pull` updates everyone; use `--copy` to snapshot instead.
- **Guardrails reduce footguns; they are not a security boundary.** Keep least-privilege credentials and review diffs.
- Model IDs and a couple of Codex keys track tool versions — `make doctor` and inline comments flag what to verify.

<div align="right"><a href="#contents">↑ top</a></div>

---

## Status

**Alpha.** The core (manual, hooks, subagents, commands, MCP, plugin/marketplace) is stable
and dogfooded; the **SDLC pipeline** is newer — proven end-to-end on a pilot, but treat it as
early. Known limits, by design:
- **Humans merge & deploy** — agents stop at the PR (never auto-merge/deploy); required
  checks + 1 code-owner approval enforce this.
- **The fix loop needs `SDLC_BOT_TOKEN` to chain** — a fine-grained PAT (Contents+PRs write).
  Without it, review + one fix run but the loop doesn't auto-continue (degrades to manual).
- **Forks get review only** — the write-capable fix loop is gated to same-repo PRs; fork
  PRs receive Reviewer, Security, and Auditor but never the Builder fix push.
- **Round cap** — the loop repeats up to `SDLC_MAX_FIX_ROUNDS` (default 3), then labels
  `sdlc:needs-human` and posts a comment.
- **Cloud agents need a runner or credential** — keyless via a self-hosted runner (`claude
  -p`), or a subscription token / API key for GitHub-hosted runners.
- **Agent teams are interactive-only** — headless multi-agent coordination uses chained
  `claude -p` + `codex exec`, not teams.
- Pin to a tagged release (not `main`) for stability. Report issues via the templates.

<div align="right"><a href="#contents">↑ top</a></div>

---

## Docs

| Doc | What |
|---|---|
| [00 · Philosophy](docs/00-philosophy.md) | the operating beliefs |
| [01 · Architecture](docs/01-architecture.md) | how each piece maps into the runtime |
| [02 · Cost & models](docs/02-cost-and-models.md) | the delegation/routing model |
| [03 · Customize](docs/03-customize.md) | add your own agents/commands/skills |
| [04 · MCP](docs/04-mcp.md) | single-source server parity |
| [05 · Plugin](docs/05-plugin.md) | marketplace + what plugins can/can't ship |
| [06 · LSP](docs/06-lsp.md) | language-server intelligence |
| [07 · Practices](docs/07-practices.md) | cited best practices (and what's folklore) |
| [08 · Defaults](docs/08-defaults.md) | making it the default for new repos |
| [09 · SDLC](docs/09-sdlc.md) | autonomous governed agents (plan→build→review→audit→QA), human-gated |
| [10 · Roadmap](docs/10-roadmap.md) | agentic directions — review-routing, scheduled agents, agent teams, cross-repo memory (grounded in real harness primitives) |
| [11 · Using compass](docs/11-using-compass.md) | **start here** — install in one command, the pieces, daily workflow, cost-effective + productive habits |
| [12 · Every agent](docs/12-every-agent.md) | LLM/IDE-agnostic — one manual for Claude Code, Codex, Gemini CLI, Cursor, Windsurf, Copilot (AGENTS.md standard) |
| [ADRs](docs/adr/) | load-bearing decisions (cross-repo memory; autonomous-loop trust boundary) |
| [Alpha](docs/alpha.md) | onboarding guide for alpha users |
| [Demo](demo/README.md) | render the terminal GIF with vhs |

<div align="center"><sub>MIT · built to be shared</sub></div>
