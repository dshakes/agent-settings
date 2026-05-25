#!/usr/bin/env bash
# checkpoint-wip.sh — Stop hook. OPT-IN (not wired by default).
#
# Snapshots uncommitted work to a scratch ref after each turn, so a crash or context
# compaction loses nothing. NON-INTRUSIVE: uses `git stash create` (builds a commit object
# without touching your index or working tree) and parks it under refs/compass/wip/<branch>.
# It never alters your branch history; restore with `git stash apply <sha>` if needed.
#
# Enable: add to settings.json under hooks.Stop (see docs/10-roadmap.md §7).
# Must never fail the session — every step degrades to exit 0.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

INPUT="$(cat)"
CWD="$(json_get "$INPUT" '.cwd')"
cd "${CWD:-$PWD}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Nothing to snapshot?
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
  exit 0
fi

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
snap="$(git stash create "compass-wip: $(date -u +%FT%TZ)" 2>/dev/null || true)"
[ -n "$snap" ] || exit 0
git update-ref "refs/compass/wip/$branch" "$snap" 2>/dev/null || true
exit 0
