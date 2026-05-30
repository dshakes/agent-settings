# compass-memory — cross-repo agent memory (LOCAL v1, opt-in)

> ✅ **Accepted as a local, opt-in v1** ([ADR 0001](../../docs/adr/0001-cross-repo-memory.md),
> security-reviewed). The security-critical logic (`store.py`) is **unit-tested in CI**
> (`test_store.py`). **Not enabled by default** — registered with `autoRegister:false`; a human
> turns it on per-repo. `server.py` is thin MCP glue (needs the SDK to run).
> **A networked/team version is a separate, gated decision** (encryption, authn, etc. — see ADR).

The only sanctioned way to get "GBrain"-style shared knowledge (Claude Code has no native
cross-repo memory). **Never** a hard dependency of compass.

## Guarantees & limits (read before enabling)
- **Trust tiers default to `deny`** (`COMPASS_MEMORY_TRUST="repo:read-write,other:read-only"`),
  most-restrictive-wins, enforced on read and write.
- **Secret scrubbing is best-effort, not a guarantee** — record() refuses text/tags/repo that
  look like credentials, but **never paste secrets** and don't rely on it.
- **Local only:** SQLite at `~/.compass-memory.db`, created `0600`, over stdio. No network
  endpoint — so trust tiers are an in-process filter, not OS access control (anyone who can read
  the file sees everything).

## Interface
- `memory_record(text, repo, tags)` — store a durable, **non-secret** learning. Denied unless
  the repo's trust tier is `read-write`.
- `memory_search(query, repo?)` — return learnings, scoped to repos the caller may read.

## Trust tiers (default: deny)
Set `COMPASS_MEMORY_TRUST="repo-a:read-write,repo-b:read-only"`. A repo not listed is **deny**.

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
