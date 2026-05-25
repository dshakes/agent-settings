# SDLC agent registry

The governed roster. Every autonomous action is performed by one of these agents,
under its stated **mandate**, **engine**, **least-privilege tools**, and **gate**.
Names are stable; `tag` is the machine label that drives the pipeline.

> **Prime directive:** agents do all the labor; a **human approves the irreversible
> steps** — merge to a protected branch, and deploy/publish. No agent merges or
> deploys. (Enforced by branch protection + required reviews, not trust.)

| Agent | Mandate | Engine | Tag | Tools (scoped) | Gate | Runs in |
|---|---|---|---|---|---|---|
| **Planner** | Triage an issue → a concrete plan / ADR. No code. | Claude · opus | `agent:plan` | Read, Grep, Glob, WebSearch | — | GitHub-native |
| **Builder** | Fix review feedback on the PR branch; push (closes the loop). Also: `@claude` ad-hoc implement. | Claude · sonnet | `agent:build` / `agent:needs-fix` | Read, Edit, Write, Grep, Glob, Bash(build/test/git) | — | GitHub-native + local |
| **Reviewer** | Correctness/convention review; inline comments; emits `BLOCKING`/`CLEAN` verdict; drives the fix loop. | Claude · sonnet | `agent:review` | Read, Grep, Glob, Bash(git diff/log) | **required check** (red on Blocking) | GitHub-native + local |
| **Auditor** | Independent cross-audit (second opinion). No edits. | Codex · gpt-5.5 | `agent:audit` | read-only sandbox | — | GitHub-native |
| **Security** | Secrets / authz / injection / tenancy. Advisory (does not gate merge). | Claude · opus | `agent:security` | Read, Grep, Glob, Bash(git diff) | — | GitHub-native + local |
| **QA** | Run the test suite; fail the check on test failure. | auto-detect | `agent:qa` | test runner (go/cargo/npm/pytest/make) | **required check** (red on failure) | GitHub-native + local |
| **Releaser** | Changelog + version bump on the PR branch. Never tags, publishes, or merges. | Claude · sonnet | `agent:release` | Read, Edit, Bash(git, gh) | **human approve** | GitHub-native |

## The closed loop (review ⇄ fix)

The Reviewer and Builder are wired into an automatic feedback loop on every PR push:

```
open PR / push
     │
     ▼
Reviewer (every push) ──── CLEAN ────▶ label: agent:reviewed-clean
Security (open/reopen)                     │
Auditor  (open/reopen)                     ▼
QA       (every push)              [required checks green]
                                           │
     ▲                                     ▼
     │                              human merge (gated)
     │
Reviewer ── BLOCKING ──▶ label: agent:needs-fix
                               │
                               ▼ (triggers sdlc-fix.yml — same-repo PRs only)
                         Builder reads PR comments,
                         fixes on the PR's own branch,
                         pushes (re-triggers Reviewer)
                               │
                    ┌──────────┘
                    │  repeat up to SDLC_MAX_FIX_ROUNDS (default 3)
                    │  each round: label sdlc:round-N, sdlc:fixing
                    │
                    └── cap hit ──▶ label: sdlc:needs-human
                                   (human resolves, then re-pushes or re-labels)
```

**Loop labels** (set by agents, not humans):

| Label | Set by | Meaning |
|---|---|---|
| `agent:needs-fix` | Reviewer | Blocking findings found; triggers Builder |
| `agent:reviewed-clean` | Reviewer | No Blocking findings this round |
| `sdlc:fixing` | Builder | Fix in progress (in-flight marker) |
| `sdlc:round-N` | Builder | Round counter (N = 1..SDLC_MAX_FIX_ROUNDS) |
| `sdlc:needs-human` | Builder | Round cap hit; human intervention needed |

**The loop requires `SDLC_BOT_TOKEN`** (a fine-grained PAT: Contents=write, Pull
requests=write on the repo). GitHub will not let a push or label set with the default
`GITHUB_TOKEN` re-trigger another workflow (its built-in recursion guard). Without the PAT,
review + one fix still run, but the loop stops there — human pushes or `@claude` to continue.

**Fork PRs** get review, security, and audit but never the write-capable fix loop
(`sdlc-fix.yml` is gated to `head.repo == repo`).

## Pipeline (label state machine — full)
```
issue ──▶ [agent:plan] ──▶ Builder opens PR
                                 │
                           ┌─────┴──────────────────────────────────────────────────┐
                           │  on every push                                          │
                           │  Reviewer ─ CLEAN ─▶ agent:reviewed-clean              │
                           │      │                                                  │
                           │  BLOCKING                                               │
                           │      ▼                                                  │
                           │  agent:needs-fix ──▶ Builder ──▶ push ──▶ (loop back)  │
                           │  (or sdlc:needs-human when cap hit)                    │
                           │                                                         │
                           │  on open/reopen: Security (advisory) + Auditor         │
                           │  on every push:  QA (required check)                   │
                           └─────────────────────────────────────────────────────────┘
                                 │ both required checks green + 1 code-owner approval
                                 ▼
                           [human merge gate]
                                 │
                           [agent:release] ──▶ Releaser preps CHANGELOG/version
                                 │
                           [human tag + deploy gate]
```

- **Coordination medium:** the PR — labels advance state, comments carry each agent's output.
- **Cross-audit:** flip Reviewer ↔ Auditor to audit a Codex-authored branch with Claude.
- **`orchestrate.sh`** (local): runs Planner → Builder → Reviewer → Auditor → Security → QA
  → opens a PR. The Reviewer/Security/QA local agents are direct `claude -p` / `codex exec`
  calls; the closed label-loop is GitHub-native only.

## Governance invariants
1. **Least privilege.** Each workflow sets explicit minimal `permissions`; each agent gets
   only the tools in its row. Default token is read-only; writes are per-job.
2. **Human owns the irreversible.** Merge to protected branches and deploy require human
   approval (branch protection + required reviews + protected Environments). `setup.sh
   --protect` sets required checks `review` + `qa` + 1 code-owner approval.
3. **Untrusted input.** PR titles/bodies/comments/diffs are treated as hostile — agents are
   told to ignore embedded instructions; `pull_request_target` with untrusted checkout is
   never used.
4. **Budget + loop guards.** Every headless run caps `--max-turns` and `--max-budget-usd`;
   `SDLC_MAX_FIX_ROUNDS` (default 3) caps the auto-fix loop; hitting the cap labels
   `sdlc:needs-human` and posts a comment.
5. **`SDLC_BOT_TOKEN`** — a fine-grained PAT (Contents+PRs write) is required for the loop
   to chain. Without it the workflow degrades gracefully (one round, then manual).
6. **Audit trail.** Every agent action is a commit, review, or labeled comment — fully logged.
