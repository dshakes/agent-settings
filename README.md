# agent-settings

[![ci](https://github.com/dshakes/agent-settings/actions/workflows/ci.yml/badge.svg)](https://github.com/dshakes/agent-settings/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-8A63D2.svg)](docs/05-plugin.md)

A production-grade, **cloneable** configuration for [Claude Code](https://claude.com/claude-code)
and [Codex](https://openai.com/codex) — tuned for serious, polyglot software work
and kept honest. Clone it, run `make install`, and your agents pick up a
core operating manual, safety guardrails, auto-formatting,
cost-aware model routing, a roster of specialist subagents, and a set of
workflow commands.

> No magic, no fabricated "secret configs." Everything here is built on
> **documented** Claude Code / Codex features and battle-tested patterns. Read
> any file before you trust it — that's the point of shipping it as source.

**Two ways to install** — pick one (don't run both; hooks would double-fire):

```bash
# A) Full setup (recommended) — clone + symlink into ~/.claude and ~/.codex.
#    Includes the CLAUDE.md operating manual, permissions, statusline, Codex parity.
git clone https://github.com/dshakes/agent-settings ~/agent-settings && cd ~/agent-settings
make dry-run     # see exactly what will change
make install     # backs up anything it replaces
make doctor      # validate everything

# B) Plugin only (zero-config team rollout of the machinery — subagents,
#    commands, hooks, skill, output style, MCP). Can't carry memory/permissions.
/plugin marketplace add dshakes/agent-settings
/plugin install core@agent-settings
```

See [`docs/05-plugin.md`](docs/05-plugin.md) for what each method can and can't ship.

---

## Why this exists

The gap between a default agent and a great one isn't the model — it's the
**configuration around it**: what it knows by default, what it's allowed to do,
what it does automatically, and which model does which job. This repo encodes that
configuration so you don't reinvent it per machine or per teammate.

What you get on the first task:
- **It already knows how to behave** — a tight operating manual (`CLAUDE.md` /
  `AGENTS.md`) loads into every session: understand-before-changing, stay in
  scope, verify, report faithfully.
- **It can't do the catastrophic thing** — a `PreToolUse` hook blocks secret
  writes, `rm -rf /`, `curl|sh`, and force-push/hard-reset on protected branches.
- **It cleans up after itself** — a `PostToolUse` hook formats every file it edits
  with the canonical formatter for the language.
- **It costs less** — fan-out work is delegated to **Haiku/Sonnet** subagents;
  **Opus** is reserved for hard reasoning. A live status line shows session cost.
- **It has specialists** — `code-reviewer`, `security-auditor`, `debugger`,
  `architect`, `go-engineer`, `rust-engineer`, `k8s-operator`, `test-runner`,
  `docs-writer` — each with the right model and scoped tools.
- **It has workflows** — `/ship`, `/review`, `/tdd`, `/pr`, `/adr`, `/triage`,
  `/scaffold`, `/cost`.

---

## What's in the box

```
agent-settings/
├── claude/                     # → symlinked into ~/.claude
│   ├── settings.json           # model, permissions, hooks, statusline, env
│   ├── CLAUDE.md               # global operating manual (loads every session)
│   ├── statusline.sh           # model · dir · git · context · $cost
│   ├── output-styles/          # "Concise" terse tone
│   ├── agents/                 # 9 cost-tiered specialist subagents
│   ├── commands/               # /ship /review /tdd /pr /adr /triage /scaffold /cost
│   ├── skills/                 # bootstrap-agent-config (+ your own)
│   └── hooks/                  # protect-paths · format-on-edit · inject-context · notify
├── codex/                      # → symlinked/merged into ~/.codex
│   ├── config.toml             # profiles (deep/standard/cheap), sandbox posture
│   └── AGENTS.md               # same constitution as CLAUDE.md
├── mcp/
│   └── servers.json            # single-source MCP manifest → both Claude & Codex
├── templates/                  # CLAUDE.md + project .mcp.json skeletons
├── scripts/                    # doctor.sh, setup-mcp.sh, uninstall.sh
├── docs/                       # philosophy, architecture, cost, customization
├── install.sh                 # idempotent, backs up, symlink or --copy
└── Makefile
```

See [`docs/01-architecture.md`](docs/01-architecture.md) for how each piece maps
into the runtime.

---

## The hooks (balanced posture)

| Hook | Event | What it does |
|---|---|---|
| `protect-paths.sh` | PreToolUse | **Blocks** secret writes, `rm -rf /`, fork bombs, `curl\|sh`, force-push/hard-reset to `main`/`prod`. Everything else flows to normal rules. |
| `format-on-edit.sh` | PostToolUse | Formats the edited file (gofmt, rustfmt, prettier/biome, ruff, shfmt, terraform, buf). Best-effort, silent. |
| `inject-context.sh` | SessionStart | Hands Claude branch, dirty state, recent commits up front — no wasted first turn. |
| `notify.sh` | Stop / Notification | Desktop notification when a turn finishes or input is needed (macOS/Linux). |

All hooks are dependency-light (jq → python3 → grep fallback) and **never fail a
session**. Read them — they're short.

---

## Cost model

The driver runs **Opus 4.7 / high effort**. The savings come from *delegation*:

| Tier | Model | Used by | For |
|---|---|---|---|
| Cheap | Haiku 4.5 | `test-runner` | test runs, log triage, mechanical sweeps |
| Standard | Sonnet 4.6 | `code-reviewer`, `go/rust-engineer`, `docs-writer`, `k8s-operator` | most coding & review |
| Deep | Opus 4.7 | `architect`, `security-auditor`, `debugger`, driver | architecture, security, subtle bugs |

`/cost` re-plans any task to the cheapest-correct mix. More in
[`docs/02-cost-and-models.md`](docs/02-cost-and-models.md).

---

## MCP servers (kept in Claude ↔ Codex parity)

One manifest ([`mcp/servers.json`](mcp/servers.json)) registers servers in **both**
tools, skipping anything that would duplicate your existing Codex plugins.

```bash
make mcp          # register curated servers in Claude + Codex
claude mcp list   # verify health
```

Auto-registered (secret-free): **context7** (live library docs), **fetch** (URL →
markdown), **git** (structured git). Opt-in/documented: **github** (OAuth),
**postgres** (read-only, project-scoped — pre-wired for lantern via its
`.mcp.json`, gated on `LANTERN_DATABASE_URL`). Details in
[`docs/04-mcp.md`](docs/04-mcp.md).

---

## LSP — language intelligence (opt-in, Claude-only)

A companion plugin gives Claude **automatic diagnostics + navigation** (background,
zero context cost) for Go, Rust, TypeScript, and Python:

```bash
/plugin install core-lsp@agent-settings    # needs the servers on PATH
```

It's separate because it requires `gopls`/`rust-analyzer`/`typescript-language-server`/
`pyright` installed. Codex has no native LSP, so this is Claude-only — see
[`docs/06-lsp.md`](docs/06-lsp.md).

---

## Team rollout (pin the plugin in a shared repo)

Commit a project `.claude/settings.json` so everyone who opens the repo gets the
machinery — pinned to a tag for stability:

```jsonc
{
  "extraKnownMarketplaces": {
    "agent-settings": { "source": { "source": "github", "repo": "dshakes/agent-settings", "ref": "v0.2.0" } }
  },
  "enabledPlugins": { "core@agent-settings": true }
}
```

A teammate is prompted to trust the repo, then the plugin auto-enables. Anyone who
already has it globally (via `make install`) opts out per-repo in a gitignored
`.claude/settings.local.json` (`{ "enabledPlugins": { "core@agent-settings": false } }`)
to avoid double-firing hooks. This is live in the **lantern** repo. Details:
[`docs/05-plugin.md`](docs/05-plugin.md).

---

## Customizing

This is a starting point, not scripture. Fork it. The global `CLAUDE.md` has a
clearly-marked stack section you can delete if you're not polyglot AI-infra. Add
your own agents/commands/skills as plain markdown files — they're picked up
automatically. See [`docs/03-customize.md`](docs/03-customize.md).

Bootstrapping a new repo? In any project, ask Claude to run the
**`bootstrap-agent-config`** skill — it inspects the codebase and drafts a
grounded project `CLAUDE.md` + `AGENTS.md`.

---

## Safety & honesty notes

- The installer **backs up** anything it replaces into `~/.claude/backups/` and is
  idempotent. `make uninstall` removes only the symlinks it created.
- Symlink install means `git pull` updates everyone; `--copy` if you'd rather
  snapshot.
- Guardrails reduce footguns; they are **not** a security boundary. Keep using
  least-privilege credentials and review diffs.
- Model IDs and a couple of Codex keys track tool versions — `make doctor` and the
  inline comments flag what to verify on your machine.

MIT licensed. Built to be shared.
