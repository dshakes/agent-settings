#!/usr/bin/env bash
# uninstall.sh — remove symlinks this repo created. Leaves backups untouched.
set -euo pipefail
removed=0
for n in settings.json CLAUDE.md statusline.sh agents commands skills hooks output-styles; do
  t="$HOME/.claude/$n"
  if [ -L "$t" ]; then rm -f "$t"; echo "removed ~/.claude/$n"; removed=$((removed+1)); fi
done
if [ -L "$HOME/.codex/AGENTS.md" ]; then rm -f "$HOME/.codex/AGENTS.md"; echo "removed ~/.codex/AGENTS.md"; removed=$((removed+1)); fi
if [ -L "$HOME/.gemini/GEMINI.md" ]; then rm -f "$HOME/.gemini/GEMINI.md"; echo "removed ~/.gemini/GEMINI.md"; removed=$((removed+1)); fi
if [ -L "$HOME/.codex/config.toml" ]; then
  rm -f "$HOME/.codex/config.toml"; echo "removed ~/.codex/config.toml (was our template symlink)"; removed=$((removed+1))
elif [ -f "$HOME/.codex/config.toml" ]; then
  # Strip only our marker-delimited blocks (profiles + mcp); keep the user's config.
  for begin in "# >>> compass profiles >>>:# <<< compass profiles <<<" \
               "# >>> compass mcp >>>:# <<< compass mcp <<<"; do
    b="${begin%%:*}"; e="${begin##*:}"
    if grep -qF "$b" "$HOME/.codex/config.toml"; then
      tmp="$(mktemp)"; sed "/$b/,/$e/d" "$HOME/.codex/config.toml" >"$tmp" && mv "$tmp" "$HOME/.codex/config.toml"
      echo "stripped '$b' block from ~/.codex/config.toml"; removed=$((removed+1))
    fi
  done
fi
# Claude MCP servers we registered (user scope)
for s in context7 fetch git; do
  if claude mcp get "$s" >/dev/null 2>&1; then claude mcp remove "$s" --scope user >/dev/null 2>&1 && echo "removed claude mcp: $s" && removed=$((removed+1)); fi
done
echo "Removed/cleaned $removed item(s). Restore prior config from ~/.claude/backups/ if needed."
