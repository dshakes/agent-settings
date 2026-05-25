# Scheduled routines — agents on a timer

Cron-scheduled agents that keep a repo healthy and **open PRs/issues into the normal SDLC
loop** (so review/QA/human-merge still apply). They **never merge or deploy**. Opt-in —
they're not installed by `setup.sh --all`.

| Routine | Schedule | Does | Writes | Opens |
|---|---|---|---|---|
| `babysit-prs.yml` | every 6h | nudge PRs stuck in `sdlc:needs-human` / red checks | comments | — |
| `dep-refresh.yml` | weekly (Mon) | bump deps, test, summarize | a branch | a PR |
| `flaky-triage.yml` | nightly | cluster recent CI failures into flakes | — | an issue |
| `doc-freshness.yml` | weekly (Mon) | fix docs that drifted from code | a branch | a PR |

## Install
```bash
cd <your-repo>
~/compass/sdlc/setup.sh --routines        # copies these into .github/workflows/ + commits
# or copy individually:
cp ~/compass/sdlc/routines/babysit-prs.yml .github/workflows/
```
They use the same secrets as the pipeline (`CLAUDE_CODE_OAUTH_TOKEN`, `SDLC_BOT_TOKEN`,
and `OPENAI_API_KEY` only if a routine calls Codex). Each has a `workflow_dispatch:` trigger
so you can run it on demand from the Actions tab before trusting the cron.

## Safety
- **Budget caps** (`--max-budget-usd`, `--max-turns`) on every routine — scheduled spend is
  bounded. Watch the first few runs in the Actions tab / `claude agents`.
- **Least privilege**: `babysit`/`flaky` are read-mostly; `dep-refresh`/`doc-freshness` push
  only to their own `routine/*` branch, never a protected branch.
- **No merge, no deploy** — every routine stops at a PR or comment. Humans own the rest.
- Start with **one** (`babysit-prs`), confirm the cadence/cost, then add more.

## Local alternative (no GitHub Actions)
On a machine where `claude` is logged in, the [`/schedule`](https://docs.claude.com) skill
(Claude Code ≥ v2.1.147) runs the same idea as a local routine, e.g.
`/schedule "nudge PRs stuck in sdlc:needs-human; comment only, never merge" --interval "0 */6 * * *"`,
visible in `claude agents`.
