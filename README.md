<div align="center">

# 🧭 compass

**One configuration that makes Claude Code and Codex behave like your best engineer — by default, in every repo.**

[![ci](https://github.com/dshakes/compass/actions/workflows/ci.yml/badge.svg)](https://github.com/dshakes/compass/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/dshakes/compass?color=8A63D2)](https://github.com/dshakes/compass/releases)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-8A63D2.svg)](docs/05-plugin.md)
[![AGENTS.md](https://img.shields.io/badge/AGENTS.md-compatible-2ea44f.svg)](https://agents.md/)

</div>

<p align="center">
  <img src="demo/preview.gif" alt="compass demo — make doctor, status line, guardrail, subagents and commands" width="900">
</p>

<sub>Recorded with <a href="https://github.com/charmbracelet/vhs">vhs</a> from <a href="demo/demo.tape"><code>demo/demo.tape</code></a> — run <code>make demo</code> to re-render. Static version: <a href="assets/hero.svg"><code>assets/hero.svg</code></a>.</sub>

> **No magic, no fabricated "secret configs."** Every piece is a *documented* Claude Code / Codex feature, assembled with care and cited where it matters. Read any file before you trust it — that's the point of shipping it as source.

---

## Contents

- [Quickstart](#quickstart)
- [Why compass](#why-compass)
- [What's inside](#whats-inside)
- [The hooks](#the-hooks)
- [Cost model](#cost-model)
- [MCP servers](#mcp-servers)
- [Language servers (LSP)](#language-servers-lsp)
- [New or existing repos](#new-or-existing-repos)
- [Team rollout](#team-rollout)
- [Cross-tool: one source](#cross-tool-one-source)
- [Grounded in published practice](#grounded-in-published-practice)
- [Customizing](#customizing)
- [Safety and honesty](#safety-and-honesty)
- [Docs](#docs)

---

## Quickstart

Pick **one** path — running both double-fires the hooks.

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

→ [What each method can and can't ship](docs/05-plugin.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## Why compass

The gap between a default agent and a great one isn't the model — it's the **configuration around it**: what it knows, what it's allowed to do, what it does automatically, and which model does which job. compass encodes that once so you don't rebuild it per machine or per teammate.

<details>
<summary><strong>What you get on the first task →</strong></summary>

- **It already knows how to behave** — a tight operating manual loads every session: understand-before-changing, stay in scope, verify, report faithfully.
- **It can't do the catastrophic thing** — a `PreToolUse` hook blocks secret writes, `rm -rf /`, `curl|sh`, and force-push/hard-reset on protected branches.
- **It cleans up after itself** — edits are auto-formatted (gofmt, rustfmt, prettier/biome, ruff, …).
- **It costs less** — fan-out goes to Haiku/Sonnet subagents; Opus is reserved for hard reasoning; a status line shows live cost.
- **It has specialists** — code-reviewer, security-auditor, debugger, architect, go/rust-engineer, k8s-operator, test-runner, docs-writer.
- **It has workflows** — `/ship` `/review` `/tdd` `/pr` `/adr` `/triage` `/scaffold` `/cost`.

</details>

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
    "compass": { "source": { "source": "github", "repo": "dshakes/compass", "ref": "v0.4.0" } }
  },
  "enabledPlugins": { "core@compass": true }
}
```

A teammate is prompted to trust the repo, then it auto-enables. Anyone who already has it globally opts out per-repo in a gitignored `.claude/settings.local.json` (`{"enabledPlugins":{"core@compass":false}}`) to avoid double-firing hooks. **Live in the lantern repo.** → [Plugin guide](docs/05-plugin.md)

<div align="right"><a href="#contents">↑ top</a></div>

---

## Cross-tool: one source

`AGENTS.md` — the open standard Codex and 20+ agents read — is a **symlink to `CLAUDE.md`**, globally (`~/.codex/AGENTS.md` → `~/.claude/CLAUDE.md`, byte-identical) and per-repo. Edit the manual once; both tools read the same instructions, no drift.

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
| [Demo](demo/README.md) | render the terminal GIF with vhs |

<div align="center"><sub>MIT · built to be shared</sub></div>
