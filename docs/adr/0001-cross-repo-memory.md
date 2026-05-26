# ADR 0001 — Cross-repo agent memory via an MCP knowledge server

- **Status:** **Accepted for a LOCAL, opt-in v1** (stdio + SQLite, not registered by default).
  A **networked/team version remains a separate, gated decision** (see Posture).
- **Date:** 2026-05-25
- **Deciders:** repo owner (approved local v1)

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

## Security review (gate satisfied for local v1)
Reviewed by the `security-auditor` agent (2026-05-25). Verdict: **safe to ship as the opt-in,
local, stdio v1** after two must-fixes, now applied:
- **DB file is `0600`** (+ WAL/SHM sidecars) — trust tiers are an in-process filter, not OS
  access control. (`store.py:connect`)
- **Trust tiers are most-restrictive-wins** on duplicate entries — no privilege escalation via
  config drift. (`store.py:trust_tier`)
- Redaction reworded as **best-effort, not a guarantee**; patterns widened (connection-string
  creds, provider key prefixes, long hex/base64); every stored field is scanned; LIKE wildcards
  escaped; repo ids validated. Logic is unit-tested (`test_store.py`, in CI).

**Hard gate before any networked/team version** (per the review): encryption-at-rest, endpoint
authn/authz, write-identity derived from authenticated context (not a request field),
prompt-injection containment on read-back, audit logging, and a materially stronger redaction
layer. None exist today and v1 ships none — it is local and single-user by design.

## Posture
- **v1 is real but opt-in:** [`mcp/compass-memory/`](../../mcp/compass-memory/) (`store.py` tested,
  `server.py` thin MCP glue). Registered in `mcp/servers.json` with `autoRegister:false` — a human
  enables it per-repo at project scope; never global, never automatic.
- **The record/inject hooks** (`Stop`/`SessionStart`) and the **networked/Postgres+pgvector team
  option** are **out of scope for v1** and blocked on the hard gate above. For now, Claude calls
  the `memory_search`/`memory_record` MCP tools when relevant.
