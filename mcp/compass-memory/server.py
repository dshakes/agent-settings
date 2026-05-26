"""compass-memory — MCP server (thin wrapper over store.py). OPT-IN, local, ADR-gated.

The security-critical logic (redaction, trust tiers) is in store.py and unit-tested by
test_store.py. This file is just the MCP glue. v1 is local stdio over SQLite — no network
endpoint. See docs/adr/0001-cross-repo-memory.md before enabling.

Run (stdio):  pip install "mcp[cli]" && python server.py
Register (opt-in, project scope):
  claude mcp add --scope project --transport stdio compass-memory -- python /abs/path/server.py
"""

from __future__ import annotations

import store

try:
    from mcp.server.fastmcp import FastMCP
except ImportError as exc:  # legible failure — this is opt-in
    raise SystemExit(
        "compass-memory needs the MCP SDK:  pip install 'mcp[cli]'"
    ) from exc

mcp = FastMCP("compass-memory")


@mcp.tool()
def memory_record(text: str, repo: str, tags: str = "") -> str:
    """Record a durable, NON-SECRET learning for a repo (requires read-write trust).
    Secrets are auto-refused; never paste credentials."""
    conn = store.connect()
    try:
        return store.record(conn, text, repo, tags)
    finally:
        conn.close()


@mcp.tool()
def memory_search(query: str, repo: str = "") -> str:
    """Search learnings, scoped to repos you may read. Returns JSON lines."""
    import json

    conn = store.connect()
    try:
        return json.dumps(store.search(conn, query, repo), indent=2)
    finally:
        conn.close()


if __name__ == "__main__":
    mcp.run()
