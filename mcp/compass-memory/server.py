"""compass-memory — REFERENCE MCP server (experimental, UNVERIFIED, not registered).

Cross-repo agent memory over local SQLite. Gated by docs/adr/0001-cross-repo-memory.md —
do NOT use in production without the ADR's security review. Naive LIKE search is a
placeholder for real vector search. Trust tiers default to deny.

Run (stdio):  pip install "mcp[cli]" && python server.py
"""

from __future__ import annotations

import json
import os
import sqlite3
import time

try:
    from mcp.server.fastmcp import FastMCP
except ImportError as exc:  # keep the failure legible — this is a reference scaffold
    raise SystemExit(
        "compass-memory reference needs the MCP SDK:  pip install 'mcp[cli]'"
    ) from exc

DB_PATH = os.environ.get(
    "COMPASS_MEMORY_DB", os.path.expanduser("~/.compass-memory.db")
)
mcp = FastMCP("compass-memory")


def _db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "CREATE TABLE IF NOT EXISTS mem("
        "id INTEGER PRIMARY KEY, text TEXT, repo TEXT, tags TEXT, ts REAL)"
    )
    return conn


def _tier(repo: str) -> str:
    """Per-repo trust tier from COMPASS_MEMORY_TRUST='repo:read-write,other:read-only'. Default deny."""
    for pair in os.environ.get("COMPASS_MEMORY_TRUST", "").split(","):
        name, _, tier = pair.partition(":")
        if name.strip() == repo and tier.strip():
            return tier.strip()
    return "deny"


@mcp.tool()
def memory_record(text: str, repo: str, tags: str = "") -> str:
    """Record a durable, non-secret learning for a repo (requires read-write trust)."""
    if _tier(repo) != "read-write":
        return f"denied: '{repo}' is not read-write (see COMPASS_MEMORY_TRUST)"
    conn = _db()
    conn.execute(
        "INSERT INTO mem(text, repo, tags, ts) VALUES(?,?,?,?)",
        (text, repo, tags, time.time()),
    )
    conn.commit()
    return "recorded"


@mcp.tool()
def memory_search(query: str, repo: str = "") -> str:
    """Search learnings (naive match — replace with vector search). Scoped to readable repos."""
    conn = _db()
    rows = conn.execute(
        "SELECT text, repo, tags, ts FROM mem WHERE text LIKE ? ORDER BY ts DESC LIMIT 20",
        (f"%{query}%",),
    ).fetchall()
    results = [
        {"text": t, "repo": r, "tags": g, "ts": ts}
        for (t, r, g, ts) in rows
        if _tier(r) != "deny" and (not repo or r == repo)
    ]
    return json.dumps(results, indent=2)


if __name__ == "__main__":
    mcp.run()
