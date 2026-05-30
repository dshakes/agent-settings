#!/usr/bin/env bash
# compass-route.sh — pick the cheapest-correct model for a task.
#
# Pure function of the input: deterministic, fast, no network, no model calls.
# Consumed by orchestrate.sh when SDLC_AUTOROUTE=1.
#
# Usage:
#   compass-route.sh [--explain] "<task description>"   # print: haiku | sonnet | opus
#   compass-route.sh --eval [evalset.tsv]               # score the router vs the labeled set
#
# --explain writes the matched reason to stderr (stdout stays pipeable).
# --eval scores against scripts/route-evalset.tsv and exits non-zero below the
#        accuracy floor (COMPASS_ROUTE_MIN_ACCURACY, default 90) — this is what
#        turns SDLC_AUTOROUTE from a guess into something CI can defend.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── tier rules (first match wins) ────────────────────────────────────────────
#
# opus  — high-stakes: architecture, security, auth, crypto, concurrency,
#         multi-tenancy, protocol design, threat modelling.
# haiku — trivial: typos, renames, formatting, comments, version bumps,
#         one-liners.
# sonnet (default) — features, fixes, tests, refactors, docs.
OPUS_PAT='architect|security|\bauth\b|authn|authz|crypto|encrypt|migration|concurren|race condition|deadlock|tenant|isolation|protocol|threat|redesign|sharding|trust model'
HAIKU_PAT='typo|rename|reformat|format this|formatter|\blint\b|comment|docstring|copyright|trailing whitespace|one.liner|\bbump\b|version in|log statement'

# route_one "<task>" -> sets globals MODEL and REASON (prints nothing). Single source
# of truth for the tiering, reused by both the CLI path and --eval. Callers must invoke
# it in the CURRENT shell (not `$(route_one …)`) so the globals propagate — a command
# substitution would run it in a subshell and the assignments would be lost.
route_one() {
  local task_lc; task_lc="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  if printf '%s' "$task_lc" | grep -qE "$OPUS_PAT"; then
    MODEL="opus"; REASON="matched opus keyword"
  elif printf '%s' "$task_lc" | grep -qE "$HAIKU_PAT"; then
    MODEL="haiku"; REASON="matched haiku keyword"
  else
    MODEL="sonnet"; REASON="no opus/haiku keyword matched — defaulting to sonnet"
  fi
}

# ── --eval: score the router against the labeled ground truth ─────────────────
run_eval() {
  local set="${1:-$HERE/route-evalset.tsv}"
  [ -f "$set" ] || { printf 'eval set not found: %s\n' "$set" >&2; exit 2; }
  # Fixed per-tier counters (bash 3.2 on macOS has no associative arrays).
  local total=0 correct=0 expected task got
  local h_t=0 h_h=0 s_t=0 s_h=0 o_t=0 o_h=0
  printf 'compass route — eval vs %s\n\n' "${set##*/}" >&2
  while IFS=$'\t' read -r expected task; do
    case "$expected" in '#'*|'') continue ;; esac
    [ -n "${task:-}" ] || continue
    route_one "$task"; got="$MODEL"
    total=$((total + 1))
    case "$expected" in haiku) h_t=$((h_t+1)) ;; sonnet) s_t=$((s_t+1)) ;; opus) o_t=$((o_t+1)) ;; esac
    if [ "$got" = "$expected" ]; then
      correct=$((correct + 1))
      case "$expected" in haiku) h_h=$((h_h+1)) ;; sonnet) s_h=$((s_h+1)) ;; opus) o_h=$((o_h+1)) ;; esac
    else
      printf '  \033[31mmiss\033[0m  want %-6s got %-6s  %s\n' "$expected" "$got" "$task" >&2
    fi
  done < "$set"

  [ "$total" -gt 0 ] || { printf 'eval set has no cases\n' >&2; exit 2; }
  local acc; acc="$(awk "BEGIN{printf \"%.1f\", 100*$correct/$total}")"
  printf '\nper-tier recall:\n' >&2
  [ "$h_t" -gt 0 ] && printf '  %-6s %d/%d\n' haiku  "$h_h" "$h_t" >&2
  [ "$s_t" -gt 0 ] && printf '  %-6s %d/%d\n' sonnet "$s_h" "$s_t" >&2
  [ "$o_t" -gt 0 ] && printf '  %-6s %d/%d\n' opus   "$o_h" "$o_t" >&2
  local floor="${COMPASS_ROUTE_MIN_ACCURACY:-90}"
  printf '\naccuracy: %s%% (%d/%d)   floor: %s%%\n' "$acc" "$correct" "$total" "$floor" >&2
  if awk "BEGIN{exit !($acc >= $floor)}"; then
    printf '\033[32mPASS\033[0m router meets the accuracy floor\n' >&2; return 0
  else
    printf '\033[31mFAIL\033[0m router below the accuracy floor — fix the rules or relabel a case\n' >&2; return 1
  fi
}

# ── arg parsing ───────────────────────────────────────────────────────────────
EXPLAIN=0; TASK=""; EVAL=0; EVALSET=""
for a in "$@"; do
  case "$a" in
    --explain) EXPLAIN=1 ;;
    --eval)    EVAL=1 ;;
    --help|-h)
      printf 'usage: compass-route.sh [--explain] "<task>"  |  compass-route.sh --eval [set.tsv]\n'
      printf 'Prints: haiku | sonnet | opus\n'; exit 0 ;;
    -*) printf 'unknown option: %s\n' "$a" >&2; exit 2 ;;
    *)  if [ "$EVAL" = 1 ]; then EVALSET="$a"; else TASK="$a"; fi ;;
  esac
done

if [ "$EVAL" = 1 ]; then run_eval "$EVALSET"; exit $?; fi

if [ -z "$TASK" ]; then
  printf 'usage: compass-route.sh [--explain] "<task description>"\n' >&2
  exit 2
fi

# Call in the current shell so MODEL/REASON propagate (see route_one's note).
route_one "$TASK"
[ "$EXPLAIN" = 1 ] && printf 'route: %s (%s)\n' "$MODEL" "$REASON" >&2
printf '%s\n' "$MODEL"
