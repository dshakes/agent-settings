# Architecture — how the pieces map into the runtime

What each file is, where it lands, and when it fires.

## Load order (every session)
1. **`settings.json`** is read (user-level `~/.claude/settings.json`, then any
   project `.claude/settings.json`, then `.local.json`). Precedence, lowest→highest:
   user → project → local → CLI args → managed.
2. **`CLAUDE.md`** (global) loads as system context, plus any project `CLAUDE.md`.
3. **`SessionStart` hook** (`inject-context.sh`) runs and injects repo orientation.
4. **`statusLine`** command runs on each render to draw the status line.
5. Agents, commands, skills, and output-styles are discovered from `~/.claude/…`
   and made available for delegation/invocation.

## The hook lifecycle
```
UserPromptSubmit ─► (model plans) ─► PreToolUse ─► [tool runs] ─► PostToolUse ─► … ─► Stop
                                        │                            │              │
                                 protect-paths.sh             format-on-edit.sh   notify.sh
                                 (block deny via              (format edited      (desktop
                                  exit 2 + JSON)               file)               notification)
```
- **PreToolUse** matches `Bash|Edit|Write|MultiEdit|NotebookEdit`. Returns
  `permissionDecision: deny` + exit 2 to block; exit 0 to defer to permission rules.
- **PostToolUse** matches `Edit|Write|MultiEdit`. Side-effect only; can't block.
- **SessionStart / Stop / Notification** are session/turn lifecycle.

Hook command strings use `$HOME/.claude/...` so they resolve through the installed
symlinks on any machine.

## Subagents (`claude/agents/*.md`)
Each is a markdown file: YAML frontmatter (`name`, `description`, `tools`, `model`)
+ a system prompt body. The driver delegates to one based on its `description`. A
subagent runs in its **own context** and returns only its conclusion — which is
why they keep the driver lean and cheap. `tools` scopes what it can touch; omit to
inherit all. `model` sets the cost tier.

## Commands (`claude/commands/*.md`)
Saved prompts invoked as `/name`. Frontmatter sets `description`, `argument-hint`,
`allowed-tools`, `model`. Body templating: `$ARGUMENTS` / `$1`, `` !`cmd` `` to
inline shell output, `@file` to inline a file. Several commands here orchestrate
subagents (e.g. `/ship` → test-runner → code-reviewer).

## Skills (`claude/skills/<name>/SKILL.md`)
A skill is a procedure the agent can auto-load by `description` or you invoke by
name. Unlike a command, it can ship a **directory** of scripts/templates
(referenced via `${CLAUDE_SKILL_DIR}`). `bootstrap-agent-config` is the example.

## Output styles (`claude/output-styles/*.md`)
Adjust the agent's tone/system prompt. Selected via `settings.json` `outputStyle`
or `/config`. "Concise" here makes responses terse and answer-first.

## Codex parity (`codex/`)
`config.toml` sets model, sandbox, approval policy, and cost profiles. `AGENTS.md`
is the same constitution as `CLAUDE.md`. Symlinking `AGENTS.md → CLAUDE.md` in a
project keeps a single source of truth across both agents.
