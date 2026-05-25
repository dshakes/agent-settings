# ADR 0001 — Cross-repo agent memory via an MCP knowledge server

- **Status:** Proposed (gates roadmap §6; not implemented/enabled)
- **Date:** 2026-05-25
- **Deciders:** repo owner (human approval required before build)

## Context
Claude Code's auto-memory (`~/.claude/projects/<repo>/memory/`) is **per-repo and
machine-local** — there is no native org-wide knowledge base. gstack's "GBrain" solves this
with an external service. We want learnings (a fixed flaky test, a gnarly build quirk, an
API's sharp edge) to be reusable across repos and teammates — without inventing a feature or
weakening a trust boundary.

This is **load-bearing**: any shared store would ingest snippets of code/context from multiple
repos, which crosses a tenancy/trust boundary. Per the operating manual, that requires an ADR
before code — hence this document.

## Decision
If/when built, cross-repo memory will be an **optional MCP server**, never a vendored hard
dependency of compass:

- **Interface:** two tools — `memory.search(query, repo?) -> [{text, repo, tags, ts}]` and
  `memory.record(text, repo, tags)`. Plus an MCP resource for browsing.
- **Transport/scope:** HTTP MCP, registered at **project scope** (`.mcp.json`) so a team opts
  in per-repo; never auto-registered globally.
- **Trust tiers (per repo):** `read-write` / `read-only` / `deny`, declared in config. A repo
  defaults to **deny** until explicitly allowed. Search results are scoped to repos the caller
  may read.
- **Write path:** a `Stop`/`SubagentStop` hook records only **durable, non-secret learnings**
  (never raw code, never secrets — same redaction posture as `protect-paths`). `SessionStart`
  injects the top-k relevant learnings as context.
- **Storage:** pluggable; start with a local SQLite/PGLite store (zero accounts) for a single
  user, with Postgres/pgvector as the team option.

## Consequences
- **Pros:** institutional memory survives across repos/sessions; less repeated debugging;
  aligns with gstack's three-layers-of-knowledge idea.
- **Cons / risks:** it's a service to run and **secure** — it sees cross-repo context, so
  encryption-at-rest, authn on the endpoint, and strict redaction are mandatory. Stale or wrong
  memories can mislead agents (mitigate: timestamps + "verify before relying", same as compass's
  memory-recall rule). Operational burden (indexing, backups).
- **Reversibility:** high — it's an opt-in MCP; remove the `.mcp.json` entry and it's gone.

## Alternatives considered
1. **Per-repo auto-memory only (status quo).** Zero infra, zero risk — but no cross-repo reuse.
2. **Symlink/import a shared `CLAUDE.md` fragment across repos.** Trivial, but static and manual;
   no search, no learning loop.
3. **Vendor a heavyweight memory service into compass.** Rejected: makes compass a service, not
   a config; couples every user to infra they didn't ask for.

## Posture
- **Not enabled by default.** A **reference scaffold** lives in [`mcp/compass-memory/`](../../mcp/compass-memory/)
  marked experimental/untested; it is **not** registered in `mcp/servers.json`.
- Building the production version is **blocked on explicit human approval** of this ADR and a
  follow-up security review of the chosen storage + endpoint.
