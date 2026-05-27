---
description: Onboard into the current repo — detect stack, install deps, get build+test green, write a grounded CLAUDE.md, and print a codebase map
argument-hint: "[optional: path to repo, defaults to current directory]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

Onboard me into this repo${ARGUMENTS:+ at $ARGUMENTS}.

Work through these steps in order. **Use cheap subagents aggressively** — Haiku for
any mechanical run (installs, test execution, grepping), Sonnet for reasoning and
writing. Ask before anything destructive; never push, merge, or deploy.

## 1 · Detect the stack
Scan the repo root for indicator files and print a one-line summary:
- `go.mod` → Go (note Go version)
- `package.json` → Node; check `pnpm-lock.yaml` / `yarn.lock` / `package-lock.json` for the package manager
- `Cargo.toml` → Rust (note edition / MSRV from the manifest)
- `pyproject.toml` or `requirements.txt` → Python; prefer `uv` if available
- `mix.exs` → Elixir; `Gemfile` → Ruby
- Multiple files → polyglot; list all

## 2 · Install dependencies
Run the appropriate install command for each detected stack.
Delegate this to a **Haiku subagent** — it's pure mechanics.
Skip gracefully if deps are already present (cache hit / lockfile unchanged).

| Stack | Command |
|-------|---------|
| Go | `go mod download` |
| Node/npm | `npm install` |
| Node/pnpm | `pnpm install` |
| Node/yarn | `yarn install` |
| Rust | `cargo fetch` |
| Python (uv) | `uv sync` |
| Python (pip) | `pip install -r requirements.txt` or `pip install -e .` |
| Elixir | `mix deps.get` |
| Ruby | `bundle install` |

## 3 · Build + test
Find the correct commands — check `Makefile` targets, `README`, `package.json` scripts,
`go.mod`, `Cargo.toml`, `pyproject.toml`. Run them via a **Haiku subagent**.
Report **PASS** or **FAIL** with the last ~10 lines of output.
Do NOT fix failing tests now — just surface them.

Typical probes (in order):
1. `make build && make test` (if a Makefile with those targets exists)
2. Stack-native: `go build ./... && go test ./...` / `cargo test` / `npm test` / `pytest -q`
3. Any `scripts.test` entry in `package.json`

## 4 · Write or refresh CLAUDE.md
Invoke the **`bootstrap-agent-config` skill** — it inspects the repo and produces a
grounded `CLAUDE.md` (build command, test command, run command, key directories,
conventions). If the skill isn't available, do it yourself:
- Read existing `CLAUDE.md` (if any); update only stale sections.
- Ground every claim in code you actually read — no hallucinated commands.
- Keep it short: a dense page beats five vague ones.

## 5 · Codebase map
End with a `## Codebase map` section printed in the chat (not written to a file):

```
## Codebase map
**Stack:** <e.g. Go 1.23, Node 22 (pnpm)>
**Build:** <exact command>
**Test:**  <exact command>
**Run:**   <exact command, or "n/a (library)">

**Entrypoints:**
  <file:line or package> — <one-sentence purpose>

**Key directories:**
  <dir/> — <what lives there>
  …

**Conventions / gotchas:**
  - <anything a new engineer must know on day 1>
```

---

> Cost discipline: Haiku handles all installs and test runs. Sonnet reasons about
> the map and CLAUDE.md. Never use Opus unless a subtle architectural question
> genuinely needs it.
