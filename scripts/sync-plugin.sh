#!/usr/bin/env bash
# sync-plugin.sh — regenerate the self-contained plugin from the canonical claude/ source.
#
# The plugin must ship REAL files (cross-repo symlinks aren't reliably followed by
# the plugin loader), so we copy from claude/ into plugins/core/.
# Authored, plugin-only files (hooks/hooks.json, .mcp.json, .claude-plugin/) are
# preserved. Run via `make sync-plugin`. `--check` exits non-zero if out of date.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/claude"
DST="$REPO/plugins/core"
CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1

sync_one() { # copy SRC/$1 -> DST/$1 (full replace)
  local rel="$1"
  rm -rf "${TMP:-}"; TMP="$(mktemp -d)"
  if [ "$CHECK" = 1 ]; then
    diff -rq "$SRC/$rel" "$DST/$rel" >/dev/null 2>&1 || { echo "out-of-date: plugins/core/$rel"; return 1; }
  else
    rm -rf "$DST/$rel"; cp -R "$SRC/$rel" "$DST/$rel"; echo "synced: $rel"
  fi
}

rc=0
for d in agents commands skills output-styles; do sync_one "$d" || rc=1; done

# Hooks: copy scripts + lib, but never touch the authored hooks.json.
if [ "$CHECK" = 1 ]; then
  for f in "$SRC"/hooks/*.sh "$SRC"/hooks/lib/*.sh; do
    rel="hooks/${f#$SRC/hooks/}"
    diff -q "$f" "$DST/$rel" >/dev/null 2>&1 || { echo "out-of-date: plugins/core/$rel"; rc=1; }
  done
else
  mkdir -p "$DST/hooks/lib"
  cp "$SRC"/hooks/*.sh "$DST/hooks/"
  cp "$SRC"/hooks/lib/*.sh "$DST/hooks/lib/"
  chmod +x "$DST"/hooks/*.sh "$DST"/hooks/lib/*.sh "$DST"/skills/*/*.sh 2>/dev/null || true
  echo "synced: hooks scripts (+lib), preserved hooks.json"
fi

[ "$CHECK" = 1 ] && { [ "$rc" = 0 ] && echo "plugin is in sync with claude/"; exit "$rc"; }
echo "Plugin regenerated at plugins/core/"
