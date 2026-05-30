# MCP servers (Claude ↔ Codex parity)

MCP (Model Context Protocol) servers give agents structured tools beyond the
built-ins. This repo keeps them in **parity across Claude Code and Codex** from a
single manifest: [`mcp/servers.json`](../mcp/servers.json). One edit, both tools.

```bash
make mcp                       # register the curated servers in both tools
./scripts/setup-mcp.sh --dry-run   # preview, change nothing
claude mcp list                # verify health
```

## How parity works
`scripts/setup-mcp.sh` reads the manifest and:
- **Claude** — runs `claude mcp add-json <name> '<cfg>' --scope user` (skips any
  already registered).
- **Codex** — appends `[mcp_servers.<name>]` to `~/.codex/config.toml` inside a
  marker block (`# >>> compass mcp >>>`), and **skips any server whose name
  collides with an existing Codex plugin** (so it never duplicates your
  github/gmail/drive plugins).

Secrets are referenced via `${ENV}` expansion — never written into config.

## Curated servers (auto-registered)

| Server | Tool | What it's for | Secret |
|---|---|---|---|
| **context7** | both | Up-to-date, version-correct docs for any library — stops "trained on an old API" mistakes | none (optional `CONTEXT7_API_KEY` for rate limits) |
| **fetch** | both | URL → clean markdown; gives Codex web-fetch parity | none |
| **git** | both | Structured git (diff/log/blame/show) as typed tools | none |

## Opt-in servers (need a secret or OAuth — documented, not auto-added)

**GitHub** (Claude only — Codex already has the github plugin):
```bash
claude mcp add --transport http github https://api.githubcopilot.com/mcp/
# completes OAuth in-app; preferred over the deprecated npm reference server
```

**Postgres (read-only)** — best as a *project* server. Wired for a project Postgres via a per-repo `.mcp.json`; it activates when you set:
```bash
export PROJECT_DATABASE_URL='postgres://readonly_user:…@host:5432/yourdb'
```
> Point it at a **read replica or read-only role**, never a write-capable prod
> credential. For another repo, copy `templates/mcp.project.json.tmpl` to
> `<repo>/.mcp.json` and set its `${DATABASE_URL}`.

## Adding your own
Add an entry to `mcp/servers.json` (set `claude`/`codex`/`autoRegister`), then
`make mcp`. Remove with `claude mcp remove <name>` and delete the Codex block
(`make uninstall` strips the whole marker block).
