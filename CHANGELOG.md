# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

## [0.7.0] — 2026-05-25

### Agentic capabilities (roadmap built — opt-in; human merge/deploy gate unchanged)
- **Work-type review routing** — `sdlc-classify.yml` labels each PR `domain:*` (haiku);
  `sdlc-design-review.yml` fires only on `domain:ui`; `route` skill mirrors it locally.
  Reviewer/Security/QA/Auditor stay always-on (routing only *adds* targeted review).
- **Scheduled maintenance agents** (`sdlc/routines/`, `setup.sh --routines`) — cron agents
  (babysit-prs, dep-refresh, flaky-triage, doc-freshness) that open PRs/issues into the loop
  and never merge.
- **Goal-oriented convergence** — `orchestrate.sh SDLC_CONVERGE=1` loops fix→re-review until
  CLEAN or `SDLC_MAX_FIX_ROUNDS` (local mirror of the cloud loop).
- **Spec/intent-driven mode** — `/spec` writes a committed spec; `orchestrate.sh SDLC_SPEC=`
  makes the build implement it and the review verify against its acceptance criteria.
- **Agent-team review** (`/team-review`, experimental) and **forked-subagent triage**
  (`debugger` + `CLAUDE_CODE_FORK_SUBAGENT=1`).
- **Opt-in hooks** — `route-intent.sh` (UserPromptSubmit: nudge ADR/security/spec on
  load-bearing prompts) and `checkpoint-wip.sh` (Stop: non-intrusive WIP snapshot). Not wired
  by default.
- **Browser agent** — opt-in Playwright `browser` MCP in `mcp/servers.json`.
- **Human-gated auto-merge** — `setup.sh --protect` enables GitHub auto-merge as an option
  (a human approves; the PR then merges when checks are green). Unattended merge-to-prod
  deliberately NOT built.
- **Cross-repo memory** — `docs/adr/0001` + reference scaffold `mcp/compass-memory/`
  (experimental, not enabled; production blocked on ADR approval + security review).
- `docs/10-roadmap.md` tracks all of the above with maturity tags; `docs/07-practices.md`
  records the adopted gstack techniques.
- **Cross-repo memory v1** — `mcp/compass-memory/` (tested `store.py` + thin `server.py`),
  opt-in, local SQLite, security-reviewed; ADR 0001 Accepted for local v1 (network gated),
  ADR 0002 records the autonomous-loop trust boundary.
- **One-command UX** — `make apply-many DIRS="~/code/*"` (`scripts/apply-repos.sh`) applies
  per-repo config across many repos at once; new hero graphic (`assets/hero.svg`);
  `docs/11-using-compass.md` ("start here" guide).

### Changed
- `claude/settings.json`: `includeCoAuthoredBy` → `false` (no Claude co-author trailer on commits).

### Added
- **Closed auto-fix loop** (`sdlc-fix.yml`) — when the Reviewer emits a `BLOCKING` verdict
  it labels the PR `agent:needs-fix`, which triggers the Builder to read all PR review
  comments, fix on the PR's own branch, and push. The push (via `SDLC_BOT_TOKEN`) re-runs
  the Reviewer. Repeats until the Reviewer is clean or the round cap is hit.
- **Verdict-driven labels + round cap** — Reviewer sets `agent:needs-fix` or
  `agent:reviewed-clean` based on a structured JSON verdict (`BLOCKING`/`CLEAN`). Builder
  tracks rounds with `sdlc:round-N` and `sdlc:fixing` labels; hitting `SDLC_MAX_FIX_ROUNDS`
  (default 3, configurable as a repo variable) labels `sdlc:needs-human` and posts a comment.
- **Five new workflows** — `sdlc-fix.yml` (Builder fix loop), `sdlc-security.yml` (Claude
  opus deep security pass, advisory), `sdlc-qa.yml` (test suite, required check),
  `sdlc-plan.yml` (Planner on `agent:plan` issue label), `sdlc-release.yml` (CHANGELOG +
  version bump on branch; never tags/publishes/merges).
- **Auditor auto-on-open** — `sdlc-audit.yml` now fires on `opened`/`reopened` in addition
  to the `agent:audit` label, so every new PR gets a Codex cross-audit automatically.
- **`SDLC_BOT_TOKEN` chaining** — all write-capable workflows use a fine-grained PAT
  (Contents+PRs write) so that pushes and labels re-trigger the Reviewer. `setup.sh
  --secrets` sets it and prints creation guidance if unset.
- **Required-status-check merge gate** — `setup.sh --protect` now sets `review` and `qa` as
  required status checks (plus 1 code-owner approval). The Reviewer check goes red on
  `BLOCKING`; QA goes red on test failure. A PR cannot merge while either is red.
- **Self-hosted closed loop** — `sdlc/selfhosted/` variants of all new workflows run the
  same label-driven loop via `claude -p` / `codex exec` on a self-hosted runner. `SDLC_BOT_TOKEN`
  is still required for the loop to chain on self-hosted (model auth is keyless; workflow
  chaining is not).

### Changed
- `sdlc/agents.registry.md` — updated agent table (7 real agents, all now backed by
  workflows), loop diagram, label state machine, and governance invariants (`SDLC_BOT_TOKEN`
  + `SDLC_MAX_FIX_ROUNDS`).
- `docs/09-sdlc.md` — added "The closed loop" section with ASCII diagram, new 8-workflow
  table, `SDLC_BOT_TOKEN` setup guide, required-status-check details, round-cap behavior,
  fork-PR gating, and expanded troubleshooting.
- `README.md` Autonomous SDLC section — describes the closed loop and `SDLC_BOT_TOKEN`
  requirement; Status known-limits updated to match reality.
- **Verification honesty** — operating manual + engineer subagents now forbid claiming a
  check passed without running it (label **UNVERIFIED** instead), and make the delegator
  re-run the gate on returned work. `claude/settings.json` pre-approves the safe validators
  (`actionlint`, `shellcheck`, `yamllint`, `bash -n`) so background subagents can self-verify.

### Fixed (found by live smoke test on a real repo)
- **Reviewer exhausted its turn budget** (`error_max_turns`) by posting per-line inline
  comments via the action — switched to a single summary comment + structured verdict
  (matches the reliable self-hosted reviewer); raised `--max-turns` and added the missing
  `--max-budget-usd`.
- **Builder fix never landed** — `claude-code-action` does not auto-push on a
  `pull_request: labeled` event; added an explicit PAT-authed commit+push step to
  `sdlc-fix.yml` so the fix reaches the PR branch and re-triggers the Reviewer.
- Verified the full loop on a live private repo: buggy PR → review BLOCKING + qa red →
  `agent:needs-fix` → Builder auto-fixed + pushed → qa green → re-review CLEAN → gated on
  human merge. (Note: workflow updates must reach the PR head branch, not only `main`.)

### Validation / testing
- **`sdlc/selftest.sh`** — runnable unit tests for the loop's control logic (round-cap from
  labels, verdict parsing for both the hosted `structured_output`/jq path and the self-hosted
  `SDLC-VERDICT` grep path). 16 assertions; it caught and fixed an empty-`structured_output`
  edge in `sdlc-review.yml` (now normalizes to `CLEAN`).
- **CI gate** — `ci.yml` now runs `actionlint` (with embedded `shellcheck`) across all
  workflows + SDLC templates and executes `sdlc/selftest.sh`, so the pipeline validates
  itself on every push. Added `.github/actionlint.yaml` (declares the `compass` runner label).
- **`sdlc/SMOKETEST.md`** — repeatable live smoke-test checklist for the GitHub-native
  behavior that can't be unit-tested (App, `structured_output`, PAT chaining, the merge gate).

## [0.6.1] — 2026-05-25

### Security / hardening
- SHA-pin all GitHub Actions (`actions/checkout`, `claude-code-action`, `codex-action`) and add Dependabot to keep them current.
- Add `docs/alpha.md` (alpha onboarding); bump lantern + default marketplace pins to v0.6.0.

## [0.6.0] — 2026-05-25

### Added
- **Keyless cloud agents** (`sdlc/selfhosted/`) — review / audit / implement workflows that
  shell out to `claude -p` / `codex exec` on a self-hosted runner (your **subscription** — no
  API key or token). `setup.sh --self-hosted`. Proven end-to-end on a pilot PR.
- **One-command onboarding** — `setup.sh --all`: labels + workflows + CODEOWNERS + commit/push
  + secrets + branch protection (via the GitHub API).
- **Subscription auth for hosted runners** — workflows accept `CLAUDE_CODE_OAUTH_TOKEN`
  (`claude setup-token`) as an alternative to an API key.
- **README Status section** (alpha + known limits) and an alpha badge.

### Fixed
- `claude-code-action` workflows need `id-token: write` (OIDC) — added to review + implement.
- Orchestrator printed the Codex audit twice; deduped a `[profiles.deep]` that an earlier
  rename had duplicated in the local Codex `config.toml`.

## [0.5.0] — 2026-05-25

### Added
- **Autonomous SDLC pipeline** (`sdlc/`, `docs/09-sdlc.md`) — a governed roster
  (Planner · Builder · Reviewer · **Codex Auditor** · Security · QA · Releaser) with
  names/tags/gates. A **headless, task-ordered orchestrator** (`sdlc/orchestrate.sh`:
  plan → build → review → Codex audit → security → QA → open PR) and **GitHub-native
  workflows** (Claude review, Codex cross-audit, `@claude` implement). Humans keep the
  merge/deploy gate (branch protection + CODEOWNERS + required reviewers). Least-privilege
  tokens, no `pull_request_target` footgun, prompt-injection hardening, budget/loop guards,
  and a `/sdlc` command.

## [0.4.0] — 2026-05-25

### Changed
- **Renamed the project to `compass`** (repo, marketplace id, install paths, lantern pin);
  plugins now install as `core@compass` / `core-lsp@compass`. Added an SVG hero + animated
  demo GIF, a navigable README (clickable TOC, collapsibles, back-to-top), and open-source
  polish (Code of Conduct, Security policy, issue/PR templates). Fixed a `protect-paths`
  false positive that blocked legitimate `rm -rf` subpaths.

## [0.3.0] — 2026-05-25

### Added
- **Cited best practices** (`docs/07-practices.md`) — adopted verifiable guidance
  from Anthropic's best-practices page, agents.md, Karpathy, and `gstack`, mapped
  to where each lives here. Tightened `CLAUDE.md` with context hygiene,
  verify-as-highest-leverage, explore→plan→code→commit, and self-improving memory.
- **New-repo defaults** (`scripts/new-repo.sh`, `docs/08-defaults.md`) — global
  auto-apply, a per-repo scaffolder, a `newrepo` shell function, and the git
  `init.templateDir` note for hooks.

### Changed
- **CLAUDE.md ↔ AGENTS.md unified to one source** — `AGENTS.md` is now a symlink to
  `CLAUDE.md` (global + per-repo), so Claude and Codex read identical instructions.

## [0.2.0] — 2026-05-25

### Added
- **`core-lsp` plugin** — opt-in language-server intelligence
  (diagnostics + navigation) for Go (gopls), Rust (rust-analyzer), TypeScript
  (typescript-language-server), and Python (pyright). Separate plugin because it
  needs the language-server binaries on `PATH`. See `docs/06-lsp.md`.
- **Team-rollout pattern** — pin the marketplace to a tag and auto-enable the
  plugin from a shared repo's `.claude/settings.json`; per-user opt-out via
  `.claude/settings.local.json`. Documented and applied to the lantern repo.

### Notes
- LSP is Claude-only — Codex has no native LSP config, so no LSP parity is claimed.

## [0.1.0] — 2026-05-25

First public release.

### Added
- **Global operating manual** (`claude/CLAUDE.md`) — core operating
  principles, safety hard-lines, and cost discipline; loads every session.
- **Guardrail + quality hooks** — `protect-paths` (PreToolUse: blocks secret
  writes, `rm -rf /`, `curl|sh`, force-push/hard-reset to protected branches),
  `format-on-edit` (PostToolUse), `inject-context` (SessionStart), `notify`.
- **9 cost-tiered subagents** — Haiku `test-runner`; Sonnet `code-reviewer`,
  `go-engineer`, `rust-engineer`, `docs-writer`, `k8s-operator`; Opus `architect`,
  `security-auditor`, `debugger`.
- **8 workflow commands** — `/ship` `/review` `/tdd` `/pr` `/adr` `/triage`
  `/scaffold` `/cost`.
- **`bootstrap-agent-config` skill** — drafts a grounded project `CLAUDE.md`.
- **Rich status line** — model · dir · git · context · session cost.
- **"Concise" output style** — terse, answer-first tone.
- **Codex parity** — `AGENTS.md` constitution + cost profiles (deep/standard/cheap),
  appended without clobbering existing Codex plugins/config.
- **MCP parity** — single-source `mcp/servers.json` → both tools; auto-registers
  context7, fetch, git; documents opt-in github (OAuth) and read-only postgres.
- **Installable plugin + marketplace** — `core@compass`,
  self-contained, regenerated from `claude/` via `make sync-plugin`.
- **Idempotent installer** with backups, `make doctor` validation, and `uninstall`.
- **CI** — validates JSON, frontmatter, plugin sync, and shellcheck on every push.

[0.6.1]: https://github.com/dshakes/compass/releases/tag/v0.6.1
[0.6.0]: https://github.com/dshakes/compass/releases/tag/v0.6.0
[0.5.0]: https://github.com/dshakes/compass/releases/tag/v0.5.0
[0.4.0]: https://github.com/dshakes/compass/releases/tag/v0.4.0
[0.3.0]: https://github.com/dshakes/compass/releases/tag/v0.3.0
[0.2.0]: https://github.com/dshakes/compass/releases/tag/v0.2.0
[0.1.0]: https://github.com/dshakes/compass/releases/tag/v0.1.0
