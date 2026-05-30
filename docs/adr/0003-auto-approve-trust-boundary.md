# ADR 0003 — Policy-gated auto-approve: the approval-step trust boundary

- **Status:** **Accepted** (shipped **off by default**; opt-in, single-repo, allowlisted)
- **Date:** 2026-05-30
- **Deciders:** repo owner
- **Supersedes nothing; extends [ADR 0002](0002-autonomous-loop-trust-boundary.md)**

## Context
[ADR 0002](0002-autonomous-loop-trust-boundary.md) made the merge/deploy gate immovable: agents
do everything *up to* the irreversible action; a human owns merge. As the fleet grows (PRs across
many repos, a 30-minute issue→fix→PR loop, a `test-architect` gate), the volume of *trivially-safe*
PRs a human must click through grows too — dependency bumps, docs, formatting. The owner wants
**safe autonomy on the approval step** without touching the merge gate. The underlying primitives
(`gh pr review --approve`, `gh pr merge --auto`) are real and available today; the question is
purely *governance* — when, if ever, may an agent advance a PR toward merge without a human, and
how do we keep that auditable and reversible.

This is a deliberate trust-boundary move, so it gets its own ADR.

## Decision
**An agent may mark a PR *eligible* for fast approval; it may never give the GitHub Approval that
satisfies branch protection, and it never merges.** Concretely:

1. **Distinct, non-load-bearing label.** The auto-approve agent sets **`agent:approve-eligible`**
   (a *new* label) and posts an explanatory comment. It must **not** reuse `sdlc:approved` — in
   `sdlc-control.yml`, `sdlc:approved` + `vars.SDLC_AUTO_MERGE=true` enqueues `gh pr merge --auto`;
   reusing it would shortcut the human approval. `agent:approve-eligible` triggers *nothing*
   automatically.
2. **The agent never authors a GitHub Approval.** Its toolset is **`gh pr comment` + `gh pr edit
   --add-label` only** — explicitly **not** `gh pr review --approve`. (A bot's own Approval *can*
   satisfy `required_approving_review_count` if the bot is a code owner; GitHub only blocks the PR
   *author* from self-approving. So a bot Approval would silently remove the human gate — forbidden.)
3. **The GitHub Approval stays human.** Branch protection still requires 1 code-owner approval from
   a human identity. `agent:approve-eligible` only tells the human "this one is safe to fast-track."
4. **Eligibility is an allowlist, all conditions AND-ed** (evaluated by a `gh`-only step — no model):
   - **Author allowlist** — PR authored by a configured trusted bot identity (e.g. the Implementer /
     `claude[bot]`), never a human's in-progress PR.
   - **Green-checks-only** — `statusCheckRollup` all green; required `review` + `qa` present + passing.
   - **Tests present** — the `test-architect` gate passed (tests generated/updated for the diff); a
     code change with **no test diff is never eligible**.
   - **Diff-scope allowlist** — touched paths match a configured globset (default **`docs/**`,
     `**/*.md` only**); destructive globs (`.github/**`, secrets, migrations, `Formula/**`) **fail
     closed**.
   - **Size cap** — diff under `SDLC_AUTOAPPROVE_MAX_LINES` (default 150).
5. **Kill switches (any disables it).** Repo var **`SDLC_AUTOAPPROVE=off` is the default**; an
   `sdlc:hold` label on the PR disables it; a fleet-wide `/hold all` disables it.
6. **Mobile veto window is real.** The eligibility comment + label land on the PR, so the maintainer
   gets a GitHub Mobile push (and an iMessage/WhatsApp DM) and can `/hold #N` before approving.
   Because the **GitHub Approval is still human**, there is always a human in the loop on the
   approval transition.

## Consequences
- **Pros:** the human's clicks shrink to *reviewing what's pre-screened safe*, not hunting; every
  step is still an auditable label/comment; nothing irreversible is automated; trivially reversible.
- **Cons:** another label + a repo var to understand; the allowlist must be curated conservatively
  (mitigated: starts docs-only, off by default, fail-closed globs).
- **Reversibility:** maximal — `SDLC_AUTOAPPROVE=off` (the default) is a complete no-op; delete the
  workflow to remove it entirely.

## Alternatives considered
1. **Agent gives the GitHub Approval (`gh pr review --approve`).** Rejected: a code-owner bot
   Approval satisfies branch protection and removes the human from the approval transition —
   indistinguishable from auto-merge-without-a-human. Out of scope for v1; would be its own ADR with
   a *distinct trusted-approver identity* separate from the PR author.
2. **Reuse `sdlc:approved`.** Rejected: it is already wired to auto-merge in `sdlc-control.yml`; a
   distinct label keeps the two paths from colliding.
3. **Blanket auto-approve on green checks.** Rejected: green CI ≠ adequate tests ≠ safe scope. The
   allowlist (author + scope + size + tests-present) is the safety, not the check rollup alone.
