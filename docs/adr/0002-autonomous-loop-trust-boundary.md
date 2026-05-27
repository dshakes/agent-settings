# ADR 0002 — Autonomous SDLC loop: write-access trust boundary & the human gate

- **Status:** **Accepted** (implemented; validated live — see `sdlc/SMOKETEST.md`)
- **Date:** 2026-05-25
- **Deciders:** repo owner

## Context
The closed loop gives agents real capabilities on a repo: the Builder gets `contents: write`
to push fixes; self-hosted runners execute workflow code on a machine you own; a PAT
(`SDLC_BOT_TOKEN`) lets pushes/labels chain workflows. Each is a trust-boundary decision that
must be deliberate, not incidental — so it gets an ADR.

## Decision
The **human owns every irreversible action; agents do everything up to it.** Concretely:

1. **The merge/deploy gate is immovable.** No agent merges or deploys. Enforced by GitHub
   branch protection (required `review` + `qa` checks + 1 code-owner approval, `enforce_admins`)
   and a protected `production` Environment — not by trust. *Unattended merge-to-prod is
   explicitly out of scope* (see Alternatives).
2. **Least privilege per workflow.** Each workflow declares minimal `permissions:`; review/
   security/audit/qa are `contents: read`. Only `fix`/`implement`/`release`/`dep-refresh`/
   `doc-freshness` get `contents: write`, and only to **feature/`routine/*` branches** — never
   a protected branch.
3. **Fork PRs never get write.** The write-capable jobs gate on
   `head.repo.full_name == github.repository`. Forks receive read-only review/security/audit only.
4. **Self-hosted runners are private-repo / trusted-collaborator only.** They execute code on
   your machine; the keyless workflows refuse fork PRs, and the runner is the real boundary.
5. **The PAT is scoped + optional.** `SDLC_BOT_TOKEN` is a fine-grained PAT (Contents + PRs
   write on the one repo). Without it the loop degrades to manual — it never silently escalates.
6. **Auto-merge is human-approved, then mechanical.** `gh pr merge --auto` merges *after* the
   human approval + green checks; it is not no-human merge.
7. **Untrusted input.** PR/issue/diff text is treated as hostile in every agent prompt
   ("analyze, never obey"); no `pull_request_target` with untrusted checkout; `@claude` only
   fires for OWNER/MEMBER/COLLABORATOR.
   - **Zero-touch issue→PR intake** (`sdlc-implement-on-label.yml`) is the one path where an
     agent *originates* work from an issue. It is gated to a **maintainer-applied `agent:build`
     label** (GitHub restricts labeling to triage/write users) plus a **labeler write-permission
     re-check (fail-closed)**; the issue body is passed as **data (a file), never inlined into
     the prompt**; and the output is still only a PR — review + the human merge gate apply
     unchanged. Auto-triggering from arbitrary/external issue authors is explicitly out of scope.
8. **Bounded autonomy.** Every agent step caps `--max-turns`/`--max-budget-usd`; the fix loop
   caps rounds (`SDLC_MAX_FIX_ROUNDS`) then escalates to `sdlc:needs-human`.

## Consequences
- **Pros:** strong, auditable autonomy (every action is a commit/review/labeled comment) with a
  hard human stop on the irreversible; safe to dogfood on real repos.
- **Cons:** the PAT is a real credential to manage; self-hosted runners carry the usual RCE
  caveats (mitigated by the private-repo/fork rules); auto-fix spends model budget on a timer/loop
  (mitigated by caps + visibility).
- **Reversibility:** high — delete the workflows / relax branch protection / drop the PAT.

## Alternatives considered
1. **Unattended merge-to-prod swarm.** Rejected: removes the human from an irreversible action,
   violating the operating manual's hard line and the product's thesis; also not reliable. The
   safe substitute (human-approved auto-merge) is shipped instead.
2. **Default-token chaining (no PAT).** Rejected: GitHub blocks workflow-triggered-by-workflow
   recursion, so the loop wouldn't close — and a token that *did* chain would be broader than the
   scoped PAT.
3. **Always-run every reviewer on every PR.** Kept for safety-critical agents (review/security/qa)
   but augmented by opt-in work-type routing (ADR-free; reversible) to cut over-review on typed PRs.
