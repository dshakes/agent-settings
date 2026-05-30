#!/usr/bin/env bash
# check-workflows.sh — structural lint for compass dynamic-workflow scripts.
#
# Workflow scripts are JS the Claude Code runtime executes (export const meta + a
# body using agent()/parallel()/pipeline()). We can't run them in CI — they need
# the workflow runtime and its injected globals — so we validate their SHAPE:
# every script must declare meta with name+description and actually orchestrate.
# Runs in CI; mirrors the style of sdlc/selftest.sh and scripts/test-cli.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Default to the shipped workflows; accept a dir arg so the FAIL paths are testable
# against a fixture (scripts/test-cli.sh) — same "prove the gate bites" convention as
# the router accuracy floor.
DIR="${1:-$ROOT/claude/workflows}"
pass=0; fail=0
ok() { printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass + 1)); }
no() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail + 1)); }

shopt -s nullglob
scripts=("$DIR"/*.js)
[ "${#scripts[@]}" -gt 0 ] || { echo "no workflow scripts found in claude/workflows/"; exit 0; }

echo "workflow scripts — structural lint:"
for f in "${scripts[@]}"; do
  rel="claude/workflows/$(basename "$f")"
  base="$(basename "$f" .js)"
  body="$(cat "$f")"

  case "$body" in *"export const meta"*) ok "$rel: declares meta" ;; *) no "$rel: missing 'export const meta'" ;; esac
  case "$body" in *"name:"*)              ok "$rel: meta.name" ;;        *) no "$rel: meta missing name" ;; esac
  case "$body" in *"description:"*)       ok "$rel: meta.description" ;; *) no "$rel: meta missing description" ;; esac

  # name must match the filename so it resolves as /<name>
  name="$(sed -n "s/.*name:[[:space:]]*['\"]\([a-zA-Z0-9-]*\)['\"].*/\1/p" "$f" | head -1)"
  if [ "$name" = "$base" ]; then ok "$rel: name matches filename ($name)"
  else no "$rel: meta.name '$name' != filename '$base' (won't resolve as /$base)"; fi

  # must actually orchestrate something
  if grep -qE 'agent\(|parallel\(|pipeline\(' "$f"; then ok "$rel: orchestrates agents"
  else no "$rel: no agent()/parallel()/pipeline() call"; fi

  # balanced braces/parens — cheap syntax smoke test (always runs)
  ob=$(tr -cd '{' <"$f" | wc -c); cb=$(tr -cd '}' <"$f" | wc -c)
  op=$(tr -cd '(' <"$f" | wc -c); cp=$(tr -cd ')' <"$f" | wc -c)
  if [ "$ob" = "$cb" ] && [ "$op" = "$cp" ]; then ok "$rel: balanced braces/parens"
  else no "$rel: unbalanced ({ $ob/$cb }) (( $op/$cp ))"; fi

  # real JS syntax check when node is present: wrap the body the way the runtime
  # does (async fn + injected globals) so top-level await/return parse cleanly.
  if command -v node >/dev/null 2>&1; then
    tmp="$(mktemp -d)"; w="$tmp/$base.mjs"
    {
      printf 'const agent=async()=>({}),parallel=async()=>[],pipeline=async()=>[],log=()=>{},phase=()=>{},workflow=async()=>({});\n'
      printf 'const args={},budget={total:null,spent:()=>0,remaining:()=>0};\n'
      printf 'export default (async()=>{\n'
      sed 's/^export const meta/const meta/' "$f"
      printf '\n})();\n'
    } >"$w"
    if node --check "$w" 2>/dev/null; then ok "$rel: valid JS syntax (node)"
    else no "$rel: JS syntax error (node --check)"; fi
    rm -rf "$tmp"
  fi
done

echo
printf 'workflow lint: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
