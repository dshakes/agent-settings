#!/usr/bin/env bash
# test-cli.sh — unit tests for the compass CLI tools (route · spend · impact) and the
# metric logger. Pure + fixture-based: no model calls, no network, no real ledger touched.
# Runs in CI. Mirrors the style of sdlc/selftest.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPASS="$ROOT/bin/compass"
pass=0; fail=0
ok() { printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass + 1)); }
no() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) no "$1 (missing '$3')" ;; esac; }

TMP="$(mktemp -d)"; export COMPASS_HOME="$TMP"
trap 'rm -rf "$TMP"' EXIT
TS="2026-05-27T10:00:00Z"

echo "route — cheapest-correct model tiering:"
eq "typo → haiku"      "$("$COMPASS" route 'fix a typo in the readme')" haiku
eq "rename → haiku"    "$("$COMPASS" route 'rename the variable foo to bar')" haiku
eq "feature → sonnet"  "$("$COMPASS" route 'add a rate limiter with tests')" sonnet
eq "refactor → sonnet" "$("$COMPASS" route 'refactor the parser module')" sonnet
eq "security → opus"   "$("$COMPASS" route 'redesign the auth trust model')" opus
eq "migration → opus"  "$("$COMPASS" route 'plan a database migration with tenant isolation')" opus

echo "spend — aggregation + budget:"
printf '%s\trepoA\tt\thaiku\t0.01\n%s\trepoA\tt\tsonnet\t0.04\n%s\trepoB\tt\topus\t0.30\n' "$TS" "$TS" "$TS" > "$TMP/spend.tsv"
J="$("$COMPASS" spend --all --json)"
has "total 0.35"   "$J" '"total":0.35'
has "haiku line"   "$J" '"haiku":0.01'
has "opus line"    "$J" '"opus":0.30'
has "no budget"    "$J" '"budget":null'
JB="$(COMPASS_BUDGET_USD=0.10 "$COMPASS" spend --all --json)"
has "budget set"   "$JB" '"budget":0.10'
EMPTY="$(COMPASS_HOME="$(mktemp -d)" "$COMPASS" spend --json)"
has "empty ledger" "$EMPTY" 'no spend logged yet'

echo "impact — benefit dashboard:"
printf '%s\tblock\trepoA\tcatastrophic delete\n%s\tblock\trepoA\tprotected branch\n%s\tformat\trepoA\tgo\n' "$TS" "$TS" "$TS" > "$TMP/metrics.tsv"
I="$("$COMPASS" impact --json)"
has "2 blocked"    "$I" '"footguns_blocked":2'
has "1 formatted"  "$I" '"files_formatted":1'
has "savings est"  "$I" 'estimated_saved'

echo "metric logger (hook hot path):"
rm -f "$TMP/metrics.tsv"
( . "$ROOT/claude/hooks/lib/common.sh"; compass_log_metric block "a reason"; compass_log_metric format py )
eq "logged 2 rows" "$(wc -l < "$TMP/metrics.tsv" | tr -d ' ')" 2
has "tab-separated block row" "$(head -1 "$TMP/metrics.tsv")" "$(printf 'block')"

echo
printf 'cli tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
