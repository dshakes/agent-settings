# Customizing

This repo is a starting point. Here's how to make it yours without fighting it.

## Add a subagent
Drop a file in `claude/agents/<name>.md`:
```markdown
---
name: my-agent
description: When the driver should delegate to me (be specific — this drives routing).
tools: Read, Grep, Glob, Bash      # omit to inherit all
model: claude-sonnet-4-6           # pick the cost tier
---
System prompt: role, method, output format, hard rules.
```
With a symlink install it's live immediately. Confirm with `/agents`.

## Add a slash command
`claude/commands/<name>.md`:
```markdown
---
description: One line shown in the / menu
argument-hint: "<what to pass>"
allowed-tools: Read, Bash(git diff:*), Task
---
Prompt body. Use $ARGUMENTS, !`shell cmd`, @file. Delegate to subagents by name.
```

## Add a skill
`claude/skills/<name>/SKILL.md` + any helper scripts in the same dir (reference
them as `${CLAUDE_SKILL_DIR}/script.sh`). Use a skill when there's a repeatable
procedure with conventions, not just a one-shot prompt.

## Tune the permission posture
In `claude/settings.json`:
- `defaultMode: "acceptEdits"` auto-applies edits. Switch to `"plan"` if you want
  to approve a plan before any work, or `"default"` for more prompting.
- Add safe, frequent commands to `permissions.allow` to cut prompts.
- Add risky ones to `ask`, dangerous ones to `deny`. The `protect-paths.sh` hook is
  the backstop for things permission patterns can't express (e.g. "force-push to
  main specifically").

## Adjust the hooks
Hooks are plain bash in `claude/hooks/`. Add a formatter to `format-on-edit.sh`,
tighten `protect-paths.sh`, or extend `inject-context.sh` to surface project-specific
context (open PRs, failing CI). Keep them fast and never let them exit non-zero
except an intentional PreToolUse block.

## Trim for a non-AI-infra stack
The global `CLAUDE.md` has a marked "STACK SECTION" — delete from that marker down
if Go/Rust/K8s aren't your world. The principles above it stand alone.

## Per-project overrides
Anything here can be overridden by a project's `.claude/settings.json` and
`CLAUDE.md`. Use `bootstrap-agent-config` to generate a grounded project `CLAUDE.md`.

## Keep it healthy
`make doctor` validates JSON, hook executability, frontmatter, and the installed
symlinks. Run it after edits.
