#!/usr/bin/env bash
# compass-route.sh — pick the cheapest-correct model for a task.
#
# Pure function of the input: deterministic, fast, no network, no model calls.
# Consumed by orchestrate.sh when SDLC_AUTOROUTE=1.
#
# Usage:
#   compass-route.sh [--explain] "<task description>"
#
# Prints EXACTLY one token to stdout: haiku | sonnet | opus
# --explain writes the matched reason to stderr (stdout stays pipeable).
set -euo pipefail

EXPLAIN=0
TASK=""

for a in "$@"; do
  case "$a" in
    --explain) EXPLAIN=1 ;;
    --help|-h)
      printf 'usage: compass-route.sh [--explain] "<task description>"\n'
      printf 'Prints: haiku | sonnet | opus\n'
      exit 0 ;;
    -*) printf 'unknown option: %s\n' "$a" >&2; exit 2 ;;
    *)  TASK="$a" ;;
  esac
done

if [ -z "$TASK" ]; then
  printf 'usage: compass-route.sh [--explain] "<task description>"\n' >&2
  exit 2
fi

# Normalise to lowercase for matching.
task_lc="$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]')"

# ── tier rules (first match wins) ────────────────────────────────────────────
#
# opus  — high-stakes: architecture, security, auth, crypto, concurrency,
#         multi-tenancy, protocol design, threat modelling.
# haiku — trivial: typos, renames, formatting, comments, version bumps,
#         one-liners.
# sonnet (default) — features, fixes, tests, refactors, docs.

OPUS_PAT='architecture|security|auth[^o]|authz|crypto|migration|concurrency|race condition|tenant|isolation|design|protocol|threat|redesign'
HAIKU_PAT='typo|rename|format|lint|comment|docstring|\blog\b|bump|version|whitespace|one.liner'

if printf '%s' "$task_lc" | grep -qE "$OPUS_PAT"; then
  MODEL="opus"
  REASON="matched opus keyword in: $OPUS_PAT"
elif printf '%s' "$task_lc" | grep -qE "$HAIKU_PAT"; then
  MODEL="haiku"
  REASON="matched haiku keyword in: $HAIKU_PAT"
else
  MODEL="sonnet"
  REASON="no opus/haiku keyword matched — defaulting to sonnet"
fi

[ "$EXPLAIN" = 1 ] && printf 'route: %s (%s)\n' "$MODEL" "$REASON" >&2

printf '%s\n' "$MODEL"
