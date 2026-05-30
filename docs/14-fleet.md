# Autonomous fleet + mobile mission-control

A fleet of opt-in, governed, scheduled GitHub Actions agents that run continuously
across your repos — scanning, fixing, and surfacing — while a **mobile
mission-control surface** keeps you in the loop from anywhere. Humans still own
every merge and deploy; that gate is fixed by ADR-0002 and enforced by GitHub
branch protection, not by trust.

This document covers what is shipped now (single-repo, config-only — Phase 0),
the cross-repo orchestration layer (Phase 1, shipped — needs `FLEET_TOKEN`), and
native iMessage/WhatsApp reply-to-command (Phase 2, shipped — local daemon, needs
a reachable bridge).

---

## The agents

Install any or all with `sdlc/setup.sh --routines`. Every routine has
`workflow_dispatch:` so you can trigger it on demand from the Actions tab
before trusting the cron.

### `test-architect` — the safety gate

**File:** `claude/agents/test-architect.md`
**Invoked by:** other agents (vuln-remediate, the SDLC Builder) before any fix
advances; also on demand via `/tdd` or "add tests for X".

This subagent generates unit and end-to-end tests, runs them, and validates that
each test actually fails without the change (so a tautological test doesn't pass the
gate). Its verdict drives the loop:

- `TEST-GATE: PASS` — behavior is covered, tests ran and passed, coverage of changed
  code did not drop.
- `TEST-GATE: FAIL — <reason>` — fix is not allowed to advance.

The hard rule: **no adequate tests → no approve/merge, no PR.** vuln-remediate will
move an untested fix into the issue rather than the PR. auto-approve will not mark
a source-change PR eligible without a test diff present.

### `vuln-remediate` — nightly security sweep

**File:** `sdlc/routines/vuln-remediate.yml`
**Trigger:** nightly at 04:00 UTC (`0 4 * * *`) + `workflow_dispatch`
**Governance:** never merges; every fix is test-gated; opens one PR and one issue per
run; ADR-0002.

On each run:

1. **Scan** — runs whichever dependency auditors match the repo's manifests:
   `govulncheck` (Go), `npm audit` / `pnpm audit` (Node), `pip-audit` (Python),
   `cargo audit` (Rust). Also reads GitHub Dependabot and code-scanning alerts via
   the API (silently skips 403/404 if the feature is off).
2. **Triage** — classifies each finding as SAFE (a version bump to a known-patched
   release with non-breaking semver delta) or NEEDS-HUMAN (breaking upgrade,
   code-logic fix, config/secret change, or anything ambiguous).
3. **Remediate** — creates a branch `routine/security-<run-id>`, applies the safe
   fixes, runs the test suite through `test-architect`. If the gate fails, the fix
   moves to the issue instead. Opens **one PR** titled
   `security: remediate N vulnerabilities (<date>)` listing each CVE, bump, and
   test result. Does not merge. Does not touch protected branches.
4. **File** — opens or updates one de-duped issue "Security sweep — <date>" listing
   the NEEDS-HUMAN findings with severity, location, and suggested remediation.
   CRITICAL/HIGH findings get a `🚨` prefix so the digest surfaces them.

Token budget: `--max-budget-usd 5.00`, `--max-turns 40`. Model: Sonnet.

### `mission-digest` — the fleet panel

**File:** `sdlc/routines/mission-digest.yml`
**Trigger:** `*/30 * * * *` (best-effort, see [Honest limits](#honest-limits)) +
`workflow_dispatch`
**Governance:** `gh`-only, no model; deterministic and free to run; `issues: write`
only; reads PRs and writes one issue. ADR-0002.

Maintains **one pinned issue** — the fleet panel — that shows every open PR's state
at a glance:

| PR | State | Title | Checks |
|---|---|---|---|
| #42 | 🟢 clean | fix: correct token expiry | SUCCESS |
| #41 | 🟠 needs-human | feat: new auth flow | FAILURE |

State is derived from labels using the same precedence order as `sdlc-control.yml`:
reviewing → clean → approve-eligible → needs-fix → hold → approved → needs-human.

The digest reconciles the **full state** every run (idempotent — GitHub cron is
best-effort, so it never assumes the previous tick ran). It @mentions the maintainer
(`FLEET_MAINTAINER` repo variable) **only when a PR newly transitions to
`sdlc:needs-human`** — one notification, not one per tick. The panel footer shows
the mobile slash-commands:

```
/hold #N · /resume #N · /approve #N · /status
```

These are handled by the existing `sdlc-control.yml` workflow (maintainers only) and
work from GitHub Mobile or any GitHub comment surface.

### `auto-approve` — policy-gated eligibility signal

**File:** `sdlc/workflows/sdlc-autoapprove.yml`
**Trigger:** `pull_request: labeled` (fires when `agent:reviewed-clean` is applied)
**Default:** **off**. Enable with repo variable `SDLC_AUTOAPPROVE=on`.
**Governance:** `gh`-only, no model; governed by ADR-0003.

When a PR is marked `agent:reviewed-clean` and `SDLC_AUTOAPPROVE=on`, this workflow
evaluates a fail-closed AND-ed allowlist:

1. **Author** — PR author is in the trusted set (default: `claude[bot]`,
   `compass-agent`, `app/claude`; override with `SDLC_AUTOAPPROVE_AUTHORS`).
2. **Green checks** — all status checks are green; any fail/error/pending/cancel
   → not eligible.
3. **Path scope** — every changed file matches the allowlist (default:
   `docs/,README,CHANGELOG,.md`) AND does not match fail-closed globs
   (`.github/*`, `*/secrets/*`, `*.tf`, `*Formula/*`, `*/migrations/*`).
   Override the allowlist with `SDLC_AUTOAPPROVE_PATHS`.
4. **Size cap** — total additions + deletions ≤ 150 lines (override:
   `SDLC_AUTOAPPROVE_MAX_LINES`).
5. **Tests present** — a source file change with no test file in the diff is never
   eligible (this is the `test-architect` gate reflected at the allowlist level).
6. **Hold veto** — `sdlc:hold` label on the PR short-circuits the entire check.

If all conditions hold: adds label `agent:approve-eligible` and posts a comment
with the rationale. That is the full output.

**It never calls `gh pr review --approve`. It never merges.** A maintainer still
gives the GitHub Approval; a human still clicks Merge. The `agent:approve-eligible`
label is an advisory signal, not a bypass of the branch-protection gate.

### Existing routines (single-line reference)

| Routine | Schedule | Does |
|---|---|---|
| `dep-refresh.yml` | weekly Mon | bumps deps, runs tests, opens a PR |
| `flaky-triage.yml` | nightly | clusters recent CI failures, opens an issue |
| `doc-freshness.yml` | weekly Mon | fixes docs that drifted from code, opens a PR |
| `babysit-prs.yml` | every 6h | nudges PRs stuck in `sdlc:needs-human` / red checks |
| `fleet-digest.yml` | `*/30` + dispatch | cross-repo: aggregates open-PR state across all fleet repos into ONE pinned panel issue in the control repo; needs `FLEET_TOKEN` |
| `issue-poller.yml` | `*/30` + dispatch | cross-repo: scans fleet repos for `agent:autofix`-labeled issues; swaps to `agent:build` to trigger that repo's zero-touch intake loop; needs `FLEET_TOKEN` |

All four install with `setup.sh --routines`; all have `workflow_dispatch:`.
Details: [`sdlc/routines/README.md`](../sdlc/routines/README.md).

---

## Mobile mission-control

> **No lantern? No problem.** The mobile layer is deliberately decoupled — compass never
> hard-depends on any one service, so it open-sources cleanly. There are three tiers:
> 1. **GitHub Mobile** — the universal baseline. Watch, approve, merge, and trigger workflows
>    from your phone with **zero extra setup**. This alone covers most of the "control from my
>    phone" need for everyone.
> 2. **Any chat backend** — `compass notify` pushes digests/alerts to **Slack, Discord, Telegram,
>    ntfy, or a generic webhook** (config-only, free, 2-minute setup; Telegram is two-way). Set
>    whichever you use; it sends to all configured backends and no-ops if none. This is the
>    recommended path for open-source users.
> 3. **lantern iMessage/WhatsApp** — the premium native-DM surface (iMessage/WhatsApp + the
>    `compass listen` reply→command loop), for those who run lantern. Entirely optional.

### GitHub Mobile (works today, zero infra)

Install the GitHub Mobile app. Because the fleet panel is a GitHub issue and the
controls are PR comments, everything works from a phone without any additional
infrastructure:

- **Push notifications** — the digest @mentions you when a PR newly needs a human;
  GitHub Mobile delivers this as a push notification.
- **View** — tap into the panel issue for the current fleet state; tap into any PR
  for Actions run logs.
- **Act** — drop a comment on any PR to steer the loop:
  - `/hold #N` — pause the auto-fix loop on PR N.
  - `/resume #N` — unpause.
  - `/approve #N` — mark it merge-ready (with `SDLC_AUTO_MERGE=true`, queues
    auto-merge; GitHub still enforces required checks + 1 code-owner approval).
  - `/status` — post the current panel state as a comment.
  - **Approve/merge** directly in the GitHub Mobile UI if you're the code owner.
- **Trigger any workflow** — Actions tab → select a workflow → "Run workflow" button.
  Works for `vuln-remediate`, `mission-digest`, `dep-refresh`, or any routine with
  `workflow_dispatch:`.

Slash-commands are handled by `sdlc/workflows/sdlc-control.yml`; no extra
configuration beyond what the SDLC pipeline already sets up.

### lantern iMessage/WhatsApp DM bridge

For consumer-grade push delivery — a DM to your own iMessage or WhatsApp thread
rather than a GitHub notification.

**Script:** `scripts/compass-notify.sh`
**Invoked as:** `compass notify "<message>"`

The script POSTs to lantern's bridge endpoint `POST /session/<tenant>/send-self`,
which delivers the message to your own iMessage or WhatsApp thread. You can send to
both bridges in one call by comma-separating the URLs.

```bash
compass notify "PR #234 green, cov 84%. Needs your approval."
echo "body from stdin" | compass notify
compass notify --dry-run "test"    # prints the request, sends nothing
```

**Config — set these as env vars where the agent runs:**

| Variable | Purpose |
|---|---|
| `COMPASS_NOTIFY_URL` | lantern bridge base URL(s), space- or comma-separated. e.g. `http://127.0.0.1:3100` (WhatsApp), `http://127.0.0.1:3200` (iMessage). Also falls back to `LANTERN_BRIDGE_URL`. |
| `COMPASS_NOTIFY_TOKEN` | bridge bearer token. Falls back to `LANTERN_BRIDGE_TOKEN`. |
| `COMPASS_NOTIFY_TENANT` | tenant ID. Falls back to `LANTERN_DEFAULT_TENANT_ID`, then the dev default UUID. |

**Unconfigured = graceful no-op (exit 0).** A digest or routine must never fail
because the phone bridge isn't wired up. Pass `--require` if you want a missing
config to be an error.

**Honest constraint:** the lantern bridge runs on your machine or LAN, not in the
cloud. DM delivery from a GitHub-hosted Actions runner needs the bridge to be
reachable from the runner — which it isn't by default. The two paths where it works
today without extra setup:

1. **Local scheduled digest** — `compass schedule` on a machine where the bridge
   is running on localhost.
2. **Self-hosted runner** — if your runner runs on the same machine as the bridge
   (or can reach it on the LAN), set the `COMPASS_NOTIFY_*` env vars in the
   runner's environment.

### Native phone control (Phase 2)

**File:** `scripts/compass-listen.mjs`
**Invoked as:** `compass listen` (long-running local daemon; Node 22, zero npm deps)

The listener has **two transports — pick by which env you set** — sharing one command
grammar, so every user gets native DM control whether or not they run lantern:

- **Telegram (universal, free, no lantern):** set `COMPASS_NOTIFY_TELEGRAM_TOKEN` + `_CHAT`.
  Make a bot via `@BotFather`, DM it once, read your chat id from
  `https://api.telegram.org/bot<token>/getUpdates`. The listener long-polls `getUpdates`
  and only acts on messages from your authorized chat. **This is the recommended open-source
  path.**
- **lantern (premium, iMessage/WhatsApp):** set `COMPASS_NOTIFY_URL` + `_TOKEN`. The listener
  subscribes to the bridge WebSocket (`/ws?tenantId=&token=`), which broadcasts inbound DMs as
  `{type:"message",data:{from,text,isGroup}}`.

When you send a slash-command in your DM, it relays the action to GitHub and replies in-thread:

| Command | What it does |
|---|---|
| `/status [owner/repo]` | Posts one-line open-PR state |
| `/approve #N [owner/repo]` | Posts `/approve` as a PR comment → `sdlc-control.yml` enforces the gate |
| `/hold #N [owner/repo]` | Posts `/hold` as a PR comment |
| `/resume #N [owner/repo]` | Posts `/resume` as a PR comment |
| `/build #N [owner/repo]` | Labels the issue `agent:build` to trigger zero-touch intake |

The listener **never approves or merges directly.** It relays to PR comments, which
the existing governed `sdlc-control.yml` workflow (ADR-0003) then executes.

**Config env vars:**

| Variable | Purpose |
|---|---|
| `COMPASS_NOTIFY_TELEGRAM_TOKEN` + `_CHAT` | Telegram transport (universal, free) |
| `COMPASS_NOTIFY_URL` + `_TOKEN` (+ `_TENANT`) | lantern bridge transport (iMessage/WhatsApp) |
| `COMPASS_FLEET_REPO` | default `owner/repo` when not specified in command |
| `COMPASS_CMD_PREFIX` | command prefix character (default `/`) |

**Honest constraints:**

- Requires `gh` authenticated locally and a reachable transport (Telegram needs only outbound
  HTTPS; lantern needs the bridge on your machine/LAN).
- lantern's bridge may also auto-reply with its own assistant on your self-chat — pause the bot
  or use a dedicated thread if that collides. (Telegram has no such conflict.)
- The daemon is verified for JS syntax and design but **UNVERIFIED end-to-end** — a live
  transport and authenticated `gh` are needed to confirm the full path.

---

## Cross-repo fleet (Phase 1 — shipped)

The cross-repo orchestration plane is shipped and lives in **one control repo**.
Two workflows loop `sdlc/fleet/repos.txt` (copy from `sdlc/fleet/repos.txt.example`):

**`sdlc/fleet/fleet-digest.yml`** — `*/30` + dispatch; `gh`-only (no model).
Loops every repo in `repos.txt`, reads its open-PR state, and aggregates it into
ONE pinned panel issue in the control repo. @mentions `FLEET_MAINTAINER` when any
repo has a new `needs-human`. Idempotent — reconciles full state each run.

**`sdlc/fleet/issue-poller.yml`** — `*/30` + dispatch; `gh`-only (no model).
Scans each repo in `repos.txt` for issues a maintainer labeled `agent:autofix`.
Swaps the label to `agent:build`, which triggers that repo's own zero-touch intake
loop (build → test-gate → PR → review). The poller never edits code or merges;
it only swaps the label (so each issue dispatches exactly once — idempotent).
`max_per_run` defaults to 5 as a cost guard.

```
# sdlc/fleet/repos.txt — one owner/name per line
dshakes/lantern
dshakes/compass
# dshakes/syntax
```

Both workflows require **`FLEET_TOKEN`** — a fine-grained PAT or GitHub App scoped
to exactly those repos with these permissions:

- **Contents: read** — to read repo state
- **Issues: write** — to update the panel issue in the control repo and swap labels on targets
- `fleet-digest` only needs Issues: write on the control repo; `issue-poller` needs Issues: write on the target repos

`FLEET_TOKEN` is a real credential and the **single external prerequisite for
cross-repo operation**. Everything single-repo needs only the existing
`SDLC_BOT_TOKEN`. Scope the PAT to exactly the repos in `repos.txt` — least
privilege.

Missed cron ticks are recovered by the next run (both workflows are idempotent).

---

## Governance

Two ADRs cover the trust boundaries:

- **[ADR-0002](adr/0002-autonomous-loop-trust-boundary.md)** — humans own merge and
  deploy; no agent calls `gh pr merge` or deploys. Enforced by GitHub branch
  protection + required code-owner approval, not by convention.
- **[ADR-0003](adr/0003-auto-approve-trust-boundary.md)** — auto-approve is off by
  default; when on, it issues a comment + label (advisory only); it never calls
  `gh pr review --approve` and never merges. The human approval step is untouched.

Structural guarantees:

- Every automated fix is test-gated by `test-architect` before a PR is opened.
- `vuln-remediate` never applies a fix with a failing test suite; it moves untested
  fixes to the issue instead.
- `auto-approve` is fail-closed: any ambiguous check (unknown check state, path not
  in allowlist) resolves to not-eligible, not to eligible.
- Least-privilege tokens: each workflow declares only the `permissions:` it actually
  uses; review/audit/digest workflows are `contents: read`.
- Fork PRs never get the write-capable Builder or auto-approve evaluation.

---

## Honest limits

**GitHub cron is best-effort.** Under load, GitHub delays or skips scheduled runs.
All loops are idempotent and dispatchable — trigger any routine manually from the
Actions tab or `gh workflow run <name>` to recover a missed tick. Never assume the
previous cron fired.

**API budget.** `*/30` across many repos can consume a significant portion of the
GitHub REST API rate limit (5,000 requests/hour per authenticated token). The digest
uses the PAT (`SDLC_BOT_TOKEN`), which has its own rate limit bucket, but at scale
(tens of repos, 2 ticks/hour) you will approach the ceiling. Monitor with
`gh api rate_limit`. Consider moving to `*/60` or dispatching from the control repo
rather than scheduling per-repo.

**Slack/Discord.** You can configure GitHub to post Actions events one-way to a
Slack or Discord channel. Interactive controls (slash-commands, buttons that trigger
workflow dispatch) require a hosted endpoint to receive the inbound webhook — not
something that can be wired up with config alone.

**A bespoke mobile console** — a custom app with a single-pane view of the fleet —
would need a custom app and backend. GitHub Mobile + the fleet panel issue is the
practical approximation that needs no extra infrastructure.

---

## Phased roadmap

### Phase 0 — this increment (single-repo, config-only)

All of the above works in a single repo with no new credentials beyond what the
existing SDLC pipeline already uses.

- `test-architect` subagent — safety gate, ships in `claude/agents/`
- `vuln-remediate` routine — nightly dep scan + auto-fix PR + issue
- `mission-digest` routine — `*/30` fleet panel, @mention on needs-human
- `auto-approve` workflow — off by default; opt in with `SDLC_AUTOAPPROVE=on`
- `compass notify` — lantern iMessage/WhatsApp bridge (graceful no-op if unconfigured)
- `sdlc/fleet/` — `repos.txt.example` + `fleet-digest.yml` + `issue-poller.yml` shipped (Phase 1; needs `FLEET_TOKEN`)

**Turn it on:**

```bash
cd <your-repo>
~/compass/sdlc/setup.sh --routines      # installs vuln-remediate, mission-digest, dep-refresh,
                                         # flaky-triage, doc-freshness, babysit-prs

gh variable set FLEET_MAINTAINER --body "your-github-username"
# gh variable set SDLC_AUTOAPPROVE --body "on"    # opt in to the approve-eligible signal

# For lantern DM (where the digest runs):
export COMPASS_NOTIFY_URL="http://127.0.0.1:3200"   # iMessage bridge, or :3100 for WhatsApp
export COMPASS_NOTIFY_TOKEN="your-bridge-token"
export COMPASS_NOTIFY_TENANT="your-tenant-id"

# Phase 1 — cross-repo fleet (in the control repo):
cp ~/compass/sdlc/fleet/repos.txt.example sdlc/fleet/repos.txt
# edit repos.txt to list your repos
gh secret set FLEET_TOKEN --body "ghp_..."          # fine-grained PAT: multi-repo read + issues:write
~/compass/sdlc/setup.sh --fleet                     # installs fleet-digest + issue-poller

# Phase 2 — iMessage/WhatsApp reply-to-command (run on the machine with the bridge):
export COMPASS_NOTIFY_URL="http://127.0.0.1:3200"
export COMPASS_NOTIFY_TOKEN="your-bridge-token"
export COMPASS_NOTIFY_TENANT="your-tenant-id"
export COMPASS_FLEET_REPO="owner/your-default-repo"
compass listen                                       # long-running daemon; Ctrl-C to stop
```

### Phase 1 — cross-repo orchestration (shipped; needs `FLEET_TOKEN`)

`sdlc/fleet/fleet-digest.yml` and `sdlc/fleet/issue-poller.yml` are in the repo.
Copy `sdlc/fleet/repos.txt.example` to `repos.txt` in your control repo, populate
it, create and store a `FLEET_TOKEN` fine-grained PAT, and install the fleet
workflows with `sdlc/setup.sh --fleet`.

### Phase 2 — native iMessage/WhatsApp reply-to-command (shipped; local daemon)

`scripts/compass-listen.mjs` is in the repo. Run `compass listen` as a persistent
local daemon on the machine where the lantern bridge is reachable. Set the
`COMPASS_NOTIFY_*` env vars and ensure `gh` is authenticated. See the
[Native phone control](#native-phone-control-phase-2) section above for the full
command grammar and constraints.
