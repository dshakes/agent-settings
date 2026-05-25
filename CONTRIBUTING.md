# Contributing

Thanks for improving compass. The bar is simple: **everything must be
real, verified, and inspectable** — no aspirational config, no fabricated claims.

## Workflow
1. Branch off `main`.
2. Make changes in the canonical source: `claude/` (settings, agents, commands,
   skills, hooks, output styles), `codex/`, `mcp/`, or `docs/`.
3. If you touched anything under `claude/{agents,commands,skills,output-styles,hooks}`,
   regenerate the plugin: `make sync-plugin`.
4. `make doctor` — must report **0 errors**. CI runs the same checks plus shellcheck.
5. Open a PR. Keep it focused; describe what you changed and how you verified it.

## Conventions
- **Subagents/commands**: a markdown file with YAML frontmatter (`name`,
  `description`, `tools`, `model`). The `description` drives delegation — make it
  specific. Pick the cheapest model tier that does the job well.
- **Hooks**: plain bash, dependency-light (jq → python3 → grep fallback), and they
  must **never fail a session** — the only intentional non-zero is a PreToolUse
  `exit 2` block. Source helpers from `lib/common.sh`.
- **Docs**: short and true. Every command must run; every path must exist.
- **Secrets**: never commit them. Use `${ENV}` references. The `.gitignore` blocks
  `*.local.*`, `.env*`, `*.key`, `*.pem`.

## Releasing
Bump `version` in `plugins/core/.claude-plugin/plugin.json`, update
`CHANGELOG.md`, tag `vX.Y.Z`, and `gh release create`. The marketplace serves the
tagged version when consumers pin it.
