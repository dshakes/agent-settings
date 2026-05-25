# SDLC agent registry

The governed roster. Every autonomous action is performed by one of these agents,
under its stated **mandate**, **engine**, **least-privilege tools**, and **gate**.
Names are stable; `tag` is the machine label that drives the pipeline.

> **Prime directive:** agents do all the labor; a **human approves the irreversible
> steps** — merge to a protected branch, and deploy/publish. No agent merges or
> deploys. (Enforced by branch protection + required reviews, not trust.)

| Agent | Mandate | Engine | Tag | Tools (scoped) | Gate |
|---|---|---|---|---|---|
| **Planner** | Triage an issue → a concrete plan / ADR. No code. | Claude · opus | `agent:plan` | Read, Grep, Glob, WebSearch | — |
| **Builder** | Implement the plan on a feature branch; open a PR. | Claude · sonnet | `agent:build` | Read, Edit, Write, Grep, Glob, Bash(build/test) | — |
| **Reviewer** | Correctness/convention review + inline comments. No edits. | Claude · sonnet | `agent:review` | Read, Grep, Glob, Bash(git diff/log) | — |
| **Auditor** | Independent cross-audit (second opinion). No edits. | **Codex** · gpt-5.5 | `agent:audit` | read-only sandbox | — |
| **Security** | Secrets / authz / injection / tenancy. No edits. | Claude · opus | `agent:security` | Read, Grep, Glob, Bash(git diff) | — |
| **QA** | Run the test suite; report failures + root-cause. | Claude · haiku | `agent:qa` | Read, Grep, Glob, Bash(test runners) | — |
| **Releaser** | Changelog, version bump, tag, deploy prep. | Claude · sonnet | `agent:release` | Read, Edit, Bash(git, gh) | **human approve** |

## Pipeline (label state machine)
```
issue ─▶ agent:plan ─▶ agent:build ─▶ agent:review ─▶ agent:audit ─▶ agent:security ─▶ agent:qa ─▶ [human merge gate] ─▶ agent:release ─▶ [human deploy gate]
                          (opens PR)   (Claude)        (Codex)         (Claude)          (Claude)
```
- **Coordination medium:** the PR — labels advance the state, comments carry each agent's
  output. Cross-tool "conversation" (Claude ↔ Codex) happens through PR comments, not a
  live channel. This makes every handoff auditable.
- **Cross-audit is symmetric:** flip Reviewer↔Auditor to have Claude audit a Codex-authored
  branch and vice-versa.

## Governance invariants
1. **Least privilege.** Each workflow sets explicit minimal `permissions`; each agent gets
   only the tools in its row. Default token is read-only; writes are per-job.
2. **Human owns the irreversible.** Merge to protected branches and deploy require human
   approval (branch protection + required reviews + protected Environments).
3. **Untrusted input.** PR titles/bodies/comments/diffs are treated as hostile — agents are
   told to ignore embedded instructions; never use `pull_request_target` with untrusted checkout.
4. **Budget + loop guards.** Every headless run caps `--max-turns` and `--max-budget-usd`;
   handoffs are idempotent (re-delivered events don't double-act).
5. **Audit trail.** Every agent action is a commit, review, or labeled comment — fully logged.
