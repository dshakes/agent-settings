#!/usr/bin/env bash
# detect-stack.sh — fast, read-only inventory of a repo for agent-config bootstrap.
# Prints a compact report. Never writes anything.
set -euo pipefail
ROOT="${1:-.}"
cd "$ROOT"

echo "# Stack inventory: $(pwd)"
echo

echo "## Languages (by file count)"
{ git ls-files 2>/dev/null || find . -type f -not -path './.git/*'; } \
  | sed -n 's/.*\.\([a-zA-Z0-9]\{1,6\}\)$/\1/p' \
  | sort | uniq -c | sort -rn | head -12 | awk '{printf "  %5s  .%s\n",$1,$2}'
echo

echo "## Build / package files present"
for f in Makefile justfile Taskfile.yml go.mod go.work Cargo.toml package.json \
         pnpm-workspace.yaml pyproject.toml requirements.txt uv.lock \
         docker-compose.yml Chart.yaml kustomization.yaml wrangler.jsonc; do
  [ -e "$f" ] && echo "  ✓ $f"
done
# also one level down for monorepos
find . -maxdepth 2 -name go.mod -o -maxdepth 2 -name Cargo.toml -o -maxdepth 2 -name package.json 2>/dev/null \
  | grep -v '^\./\(go.mod\|Cargo.toml\|package.json\)$' | head -10 | sed 's/^/  · /'
echo

echo "## Likely commands"
if [ -f Makefile ]; then
  echo "  Make targets:"; grep -E '^[a-zA-Z0-9_-]+:' Makefile | sed 's/:.*//' | sort -u | head -20 | sed 's/^/    make /'
fi
if [ -f package.json ] && command -v jq >/dev/null 2>&1; then
  echo "  npm scripts:"; jq -r '.scripts // {} | keys[]' package.json 2>/dev/null | head -20 | sed 's/^/    npm run /'
fi
[ -f go.mod ]      && echo "    go build ./...   |   go test ./..."
[ -f Cargo.toml ]  && echo "    cargo build      |   cargo test      |   cargo clippy"
[ -f pyproject.toml ] && echo "    (python) check pyproject for ruff/pytest/uv config"
echo

echo "## Architecture signals"
for f in ARCHITECTURE.md SECURITY.md THREAT_MODEL.md CLAUDE.md AGENTS.md README.md; do
  [ -e "$f" ] && echo "  ✓ $f"
done
[ -d docs/adr ]       && echo "  ✓ docs/adr/ ($(ls docs/adr 2>/dev/null | wc -l | tr -d ' ') ADRs)"
[ -d docs/decisions ] && echo "  ✓ docs/decisions/"
[ -d .github/workflows ] && echo "  ✓ CI: .github/workflows ($(ls .github/workflows 2>/dev/null | wc -l | tr -d ' ') workflows)"
echo

echo "## Top-level layout"
ls -1d */ 2>/dev/null | head -25 | sed 's/^/  /'
