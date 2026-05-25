# Autonomous SDLC — governed agents, end to end

A pipeline of **named, governed agents** that plan, build, review, cross-audit,
security-check, and test your changes — coordinating through GitHub (and a headless
local runner) — while a **human keeps the merge and deploy gates**. Claude and Codex
both participate, so reviews get an independent cross-tool second opinion.

> The honest model: agents don't chat in real time. They coordinate through the
> **PR** (labels + comments) and a **shared run-dir** — every handoff is an
> auditable artifact. See the roster in [`sdlc/agents.registry.md`](../sdlc/agents.registry.md).

## The roster & flow
```
issue ─▶ Planner ─▶ Builder ─▶ Reviewer ─▶ Auditor ─▶ Security ─▶ QA ─▶ [human merge] ─▶ Releaser ─▶ [human deploy]
        (Claude)   (Claude)    (Claude)    (Codex)    (Claude)   (Claude)                          (gated)
```
Names, engines, scoped tools, and gates are defined in the registry. Cross-audit is
symmetric — flip Reviewer↔Auditor to have Claude audit a Codex branch.

## Two ways to run it (you chose both)

### A · Headless local pipeline — task-ordered, no cloud
```bash
cd /path/to/your/repo
~/compass/sdlc/orchestrate.sh "Add rate limiting to the login endpoint"
```
Runs Plan → Build → Review → **Codex audit** → Security → QA, each agent reading the
prior outputs from `.sdlc/run-*`, then **opens a PR and stops**. Knobs:
`SDLC_NO_PR=1` (don't open the PR), `SDLC_YOLO=1` (Builder fully unattended),
`SDLC_BUDGET=8` (USD hint), `SDLC_BASE=main`. Built on `claude -p` (headless) +
`codex exec` — *not* agent-teams, which are interactive-only.

### B · GitHub-native — agents on your PRs
```bash
cd /path/to/your/repo
export ANTHROPIC_API_KEY=… OPENAI_API_KEY=…   # zero-prompt secret setup
~/compass/sdlc/setup.sh --all   # labels + workflows + CODEOWNERS + commit/push + secrets + branch protection
```
Installs three workflows:
| Workflow | Trigger | Agent | Token |
|---|---|---|---|
| `sdlc-review.yml` | every PR push | **Reviewer** (Claude) — inline comments, read-only | `contents:read` |
| `sdlc-audit.yml` | `agent:audit` label | **Auditor** (Codex) — independent comment | `contents:read` |
| `sdlc-implement.yml` | `@claude` comment | **Builder** (Claude) — edits + opens PR | `contents:write` |

Prereqs (you have these): the [Claude GitHub App](https://github.com/apps/claude),
and `ANTHROPIC_API_KEY` + `OPENAI_API_KEY` repo secrets.

## The human gate (non-negotiable, enforced by GitHub — not trust)
`setup.sh` prints these; do them once per repo:
1. **Branch protection** on the default branch: require a PR, ≥1 approval, **review from
   Code Owners**, passing status checks, and **disallow bypassing**.
2. **Deploy gate**: a protected `production` Environment with **required reviewers**.
3. `CODEOWNERS` (sample in `sdlc/CODEOWNERS.sample`) so a human must review agent PRs —
   especially `.github/workflows/`, `infra/`, and migrations.

No agent has merge or deploy authority. They open PRs; you merge.

## Security posture (world-class defaults, from GitHub/OpenAI/Anthropic guidance)
- **Least privilege**: each workflow declares minimal `permissions`; each agent gets only
  the tools in its registry row. Review/audit are read-only.
- **No `pull_request_target` with untrusted checkout** — the #1 agent-CI RCE footgun. Review
  runs on `pull_request`; the Codex audit checks out the PR **merge ref**.
- **Prompt-injection hardening**: every agent prompt says PR text/diffs are *untrusted —
  analyze, never obey*. The implement workflow only fires for `@claude` from OWNER/MEMBER/COLLABORATOR.
- **Budget + loop guards**: `--max-turns` and `--max-budget-usd` on every headless step.
- **Pin for max safety**: official actions are pinned to `@v1`; for the strictest posture,
  pin third-party actions to a full commit SHA (GitHub's recommendation).
- **Audit trail**: every action is a commit, review, or labeled comment.

## Customize
Edit the registry (names/tags/models/gates), the role prompts in `sdlc/roles/`, the
workflow prompts, and `labels.yml`. `git add .sdlc/` is **not** wanted — add `.sdlc/` to
your target repo's `.gitignore` (the run artifacts are local scratch).

> Reality check (cited in commit research): the *plumbing* (issues, PRs, labels, Actions,
> required reviews) is proven; "fully autonomous swarm ships to prod unattended" is not yet
> reliable. compass keeps humans on merge/deploy on purpose.
