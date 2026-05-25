# LSP servers (language intelligence)

Language servers give Claude Code **automatic diagnostics** (type errors, missing
imports, lint) after each edit, plus code navigation (definitions, references,
hover). It's background tooling — no model-facing tool calls and **no context-token
cost** — so it makes edits more correct without making sessions more expensive.

## Why it's a separate, opt-in plugin
LSP requires the language-server **binaries installed on your `PATH`**. Bundling
them into the main `core` plugin would force-start servers that some
teammates don't have. So they live in a companion plugin you enable deliberately:

```bash
/plugin install core-lsp@compass
```

Verified inventory (`claude plugin details core-lsp@compass`):
**4 LSP servers — gopls, rust-analyzer, typescript, pyright.**

## Prerequisites (install the servers you need)
```bash
go install golang.org/x/tools/gopls@latest                 # Go
rustup component add rust-analyzer                          # Rust
npm i -g typescript-language-server typescript              # TypeScript
npm i -g pyright                                            # Python (pyright-langserver)
```
A server with no binary simply doesn't start for that language — harmless, but
that's why this is opt-in rather than default.

## What's configured (`plugins/core-lsp/.lsp.json`)
| Server | Command | Files |
|---|---|---|
| gopls | `gopls serve` | `.go` |
| rust-analyzer | `rust-analyzer` | `.rs` |
| typescript | `typescript-language-server --stdio` | `.ts .tsx .js .jsx` |
| pyright | `pyright-langserver --stdio` | `.py` |

Add a server by adding an entry: `"<name>": { "command", "args", "extensionToLanguage" }`.

## Honest note on Codex parity
**LSP is Claude-only.** Codex (`~/.codex/config.toml`) has no native LSP
configuration section — only `[mcp_servers.*]`. So unlike MCP, there's no true
LSP parity to ship. (A community `codex-lsp` MCP server can expose LSP-over-MCP,
but it's unverified here, so we don't wire it.) The MCP parity layer
([`docs/04-mcp.md`](04-mcp.md)) remains the cross-tool story; LSP augments Claude
specifically.
