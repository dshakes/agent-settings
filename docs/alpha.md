# For alpha users

Thanks for trying **compass** — a config that makes Claude Code + Codex behave like a
senior engineer in every repo, with an optional governed, autonomous SDLC pipeline.
It's **alpha**: the core is dogfooded and stable; the SDLC pipeline is newer. Expect
rough edges, and please file them.

## Get started in 60 seconds
```bash
git clone https://github.com/dshakes/compass ~/compass && cd ~/compass
make dry-run     # see exactly what it will change
make install     # symlinks into ~/.claude + ~/.codex (backs up anything it replaces)
make doctor      # validate
```
Now every repo you open has the operating manual, guardrail hooks, specialist
subagents, workflow commands (`/ship` `/review` `/tdd` …), and MCP servers.
Prefer not to touch your global config? Install just the machinery as a plugin:
```bash
/plugin marketplace add dshakes/compass && /plugin install core@compass
```

## Try the autonomous SDLC (keyless — uses your subscription)
```bash
cd <any-repo>
~/compass/sdlc/orchestrate.sh "add input validation to <X>"
# plan → build → review → Codex cross-audit → security → QA → opens a PR you merge
```
No API key or credits needed — it runs `claude -p` / `codex exec` on your login.

## What to expect (alpha)
- **You always merge & deploy.** Agents stop at a PR. That's by design.
- **Cloud PR automation** needs a self-hosted runner (keyless) or a credential — see
  [`09-sdlc.md`](09-sdlc.md). The local pipeline above needs neither.
- **Pin a release** (e.g. `v0.6.0`), not `main`, for stability.
- It's safe to uninstall: `make uninstall` removes only what it added (backups in `~/.claude/backups/`).

## Please report
- Bugs / ideas → the issue templates (`/issues/new/choose`).
- Questions / show-and-tell → Discussions.
- Include `make doctor` output for bugs.

Honest north star: this is footgun-prevention + leverage, **not** a hands-off autopilot.
Keep reviewing diffs; that's where the value compounds.
