# compass-memory — REFERENCE scaffold (experimental)

> ⚠️ **Reference only. Not validated, not registered, not in CI, not enabled.** This is the
> starting point gated by [ADR 0001](../../docs/adr/0001-cross-repo-memory.md). Building the
> production version is **blocked on human approval of that ADR + a security review.** Treat
> `server.py` as a sketch (UNVERIFIED — it has not been run in this repo).

Cross-repo agent memory as an **optional MCP server** — the only sanctioned way to get the
"GBrain"-style shared knowledge (Claude Code has no native cross-repo memory). It is **never**
a hard dependency of compass.

## Interface
- `memory_record(text, repo, tags)` — store a durable, **non-secret** learning. Denied unless
  the repo's trust tier is `read-write`.
- `memory_search(query, repo?)` — return learnings, scoped to repos the caller may read.

## Trust tiers (default: deny)
Set `COMPASS_MEMORY_TRUST="lantern:read-write,syntax:read-only"`. A repo not listed is **deny**.

## Try it (local, single user)
```bash
pip install "mcp[cli]"
COMPASS_MEMORY_TRUST="myrepo:read-write" python mcp/compass-memory/server.py   # stdio
# register (opt-in, project scope) once you trust it:
# claude mcp add --scope project --transport stdio compass-memory -- python /abs/path/server.py
```

## Before production (per ADR 0001)
- Swap naive `LIKE` for real vector search; move storage to Postgres/pgvector for teams.
- Enforce redaction (never store code/secrets), authn on the endpoint, encryption at rest.
- Wire the record/inject hooks (`Stop`/`SessionStart`) — also opt-in.
