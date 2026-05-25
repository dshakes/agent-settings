# Security Policy

## Scope
`compass` is configuration for AI coding agents (Claude Code + Codex): hooks,
subagents, commands, skills, MCP/LSP wiring, and an installer. It ships shell
scripts that run on your machine and a `PreToolUse` guardrail.

**The guardrail hooks reduce footguns; they are not a security boundary.** They
stop common accidents (secret writes, `rm -rf /`, `curl|sh`, force-push to `main`),
not a determined attacker or a cleverly-phrased command. Keep using least-privilege
credentials and review diffs.

## Reporting a vulnerability
Please report security issues **privately** — do not open a public issue.
- Use GitHub's **Report a vulnerability** (Security → Advisories), or
- Email **chandu1221@gmail.com** with details and a reproduction.

You'll get an acknowledgment within a few days. Once a fix ships, we'll credit you
(unless you prefer to remain anonymous).

## Good practices when using compass
- Read the hooks and scripts before `make install` — that's why they're short.
- Never put secrets in `CLAUDE.md`/`AGENTS.md`; use `${ENV}` refs for MCP servers.
- Point database MCP servers at a **read-only** role or replica.
- Pin the marketplace to a tag (not `main`) for team rollouts.
