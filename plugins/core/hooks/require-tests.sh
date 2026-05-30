#!/usr/bin/env bash
# require-tests.sh — PostToolUse policy hook. OPT-IN (not wired by default).
#
# CLAUDE.md *advises* "verify before done"; only a hook *enforces* it every time.
# When a source file is edited and NO test file is touched in the current diff,
# this injects a one-line nudge to add/adjust a test (or say why none is needed).
# Advisory — it adds CONTEXT, never blocks; you stay in control of the tradeoff.
#
# Enable: add to settings.json under hooks.PostToolUse matching "Edit|Write|MultiEdit"
# (see docs/10-roadmap.md §8). Must never fail the session.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

INPUT="$(cat)"
FILE="$(json_get "$INPUT" '.tool_input.file_path')"
[ -n "$FILE" ] || exit 0

is_test() { # path looks like a test file?
  case "$1" in
    *_test.go|*_test.py|*/test_*.py|test_*.py|*.test.ts|*.test.tsx|*.test.js|*.test.jsx|\
    *.spec.ts|*.spec.tsx|*.spec.js|*_spec.rb|*Test.java|*Tests.kt|*_test.rs) return 0 ;;
    */tests/*|*/test/*|*/__tests__/*|*/spec/*) return 0 ;;
  esac
  return 1
}

is_source() { # path is code we'd expect a test for?
  case "$1" in
    *.go|*.py|*.ts|*.tsx|*.js|*.jsx|*.rs|*.java|*.rb|*.kt|*.c|*.cc|*.cpp|*.h|*.hpp) return 0 ;;
  esac
  return 1
}

# Only weigh in on source edits; an edit TO a test is exactly what we want.
is_source "$FILE" || exit 0
is_test "$FILE" && exit 0

# Need git to see the diff; if we can't, stay silent rather than nag blindly.
have git || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# If any test file is already touched this session (modified, staged, or new),
# the work is on track — say nothing.
changed="$( { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } )"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  is_test "$p" && exit 0
done <<EOF
$changed
EOF

compass_log_metric policy "test-gap: ${FILE##*/}"
emit_context "compass require-tests: '$FILE' changed but no test file is modified in this diff — add or adjust a test that exercises the new behavior, or note explicitly why none is warranted." PostToolUse
