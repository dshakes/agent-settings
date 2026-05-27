#!/usr/bin/env bash
# compass-onboard.sh — onboard an engineer into a local repo.
#
# Detects the stack, prints a plan, then runs ONE claude -p invocation (sonnet,
# acceptEdits) that installs deps, runs build+test, writes/refreshes CLAUDE.md via
# the bootstrap-agent-config skill, and prints a codebase map.
# Appends a cost row to the global spend ledger when done.
#
#   compass-onboard.sh [--dry-run] [DIR]
#   DIR defaults to "."
set -euo pipefail

# ── colour helpers ────────────────────────────────────────────────────────────
C_RST=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
C_CYAN=$'\033[38;5;39m'; C_GREEN=$'\033[38;5;42m'; C_AMBER=$'\033[38;5;214m'
C_RED=$'\033[38;5;196m'; C_VIOLET=$'\033[38;5;141m'
log()  { printf '\n%s▶ %s%s\n' "$C_CYAN" "$*" "$C_RST"; }
note() { printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
ok()   { printf '  %s✓ %s%s\n' "$C_GREEN" "$*" "$C_RST"; }
err()  { printf '%sERROR: %s%s\n' "$C_RED" "$*" "$C_RST" >&2; }

# ── arg parsing ───────────────────────────────────────────────────────────────
DRY_RUN=0; DIR="."
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      printf '%sUsage:%s compass-onboard.sh [--dry-run] [DIR]\n' "$C_BOLD" "$C_RST"
      printf '  Onboard an engineer into a repo: detect stack, install deps,\n'
      printf '  build+test, write CLAUDE.md, print codebase map.\n'
      printf '  DIR defaults to current directory.\n'
      printf '  --dry-run  Print what would happen but do nothing effectful.\n'
      exit 0 ;;
    -*) err "unknown flag: $a  (try --help)"; exit 2 ;;
    *) DIR="$a" ;;
  esac
done

# resolve to absolute path
DIR="$(cd "$DIR" && pwd)"
REPO_NAME="$(basename "$DIR")"

printf '\n%scompass · onboard%s  %s\n' "$C_VIOLET" "$C_RST" "$DIR"

# ── stack detection ───────────────────────────────────────────────────────────
log "detecting stack"

STACKS=""
PKG_MANAGER=""
INSTALL_CMDS=""
ALLOWED_BASH_TOOLS=""

# Go
if [ -f "$DIR/go.mod" ]; then
  STACKS="${STACKS:+$STACKS, }Go"
  INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }go mod download"
  ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(go mod download:*),Bash(go build:*),Bash(go test:*),Bash(go vet:*)"
fi

# Node (detect package manager from lockfile)
if [ -f "$DIR/package.json" ]; then
  if [ -f "$DIR/pnpm-lock.yaml" ]; then
    PKG_MANAGER="pnpm"
  elif [ -f "$DIR/yarn.lock" ]; then
    PKG_MANAGER="yarn"
  else
    PKG_MANAGER="npm"
  fi
  STACKS="${STACKS:+$STACKS, }Node (${PKG_MANAGER})"
  INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }${PKG_MANAGER} install"
  ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(${PKG_MANAGER}:*),Bash(npx tsc:*)"
fi

# Rust
if [ -f "$DIR/Cargo.toml" ]; then
  STACKS="${STACKS:+$STACKS, }Rust"
  INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }cargo fetch"
  ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(cargo build:*),Bash(cargo test:*),Bash(cargo clippy:*),Bash(cargo fetch:*)"
fi

# Python
if [ -f "$DIR/pyproject.toml" ] || [ -f "$DIR/requirements.txt" ]; then
  STACKS="${STACKS:+$STACKS, }Python"
  if [ -f "$DIR/pyproject.toml" ]; then
    INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }uv sync 2>/dev/null || pip install -e ."
  else
    INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }pip install -r requirements.txt"
  fi
  ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(uv:*),Bash(pip:*),Bash(pytest:*),Bash(ruff:*)"
fi

# Elixir
if [ -f "$DIR/mix.exs" ]; then
  STACKS="${STACKS:+$STACKS, }Elixir"
  INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }mix deps.get"
  ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(mix:*)"
fi

# Ruby
if [ -f "$DIR/Gemfile" ]; then
  STACKS="${STACKS:+$STACKS, }Ruby"
  INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }bundle install"
  ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(bundle:*),Bash(ruby:*),Bash(rake:*)"
fi

if [ -z "$STACKS" ]; then
  STACKS="(unknown — no go.mod / package.json / Cargo.toml / pyproject.toml / mix.exs / Gemfile found)"
fi

printf '  %sDetected stack:%s %s\n' "$C_BOLD" "$C_RST" "$STACKS"

# ── plan ──────────────────────────────────────────────────────────────────────
log "plan"
note "1. Install dependencies  ($INSTALL_CMDS)"
note "2. Find + run build and test commands; report pass/fail"
note "3. Write or refresh CLAUDE.md via the bootstrap-agent-config skill"
note "4. Print a codebase map: entrypoints, key directories, exact build/test/run commands"

if [ "$DRY_RUN" = 1 ]; then
  printf '\n%s--dry-run: stopping here.%s\n' "$C_AMBER" "$C_RST"
  exit 0
fi

# ── require claude CLI ────────────────────────────────────────────────────────
if ! command -v claude >/dev/null 2>&1; then
  err "claude CLI not found on PATH."
  note "Install it: https://docs.anthropic.com/en/docs/claude-code/getting-started"
  exit 1
fi

# ── build allowedTools list ───────────────────────────────────────────────────
# Always include: Read, Edit, Write, Grep, Glob, and safe git inspection.
# Stack-specific bash tools are appended above.
BASE_TOOLS="Read,Edit,Write,Grep,Glob,Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(make:*)"
if [ -n "$ALLOWED_BASH_TOOLS" ]; then
  ALL_TOOLS="${BASE_TOOLS},${ALLOWED_BASH_TOOLS}"
else
  ALL_TOOLS="$BASE_TOOLS"
fi

# ── prompt ────────────────────────────────────────────────────────────────────
PROMPT="You are onboarding an engineer into the repo at: $DIR
Detected stack: $STACKS

Do these four things IN ORDER — delegate mechanical steps to cheap subagents to keep cost low:

1. INSTALL DEPS: Run the dependency install for the detected stack. Suggested commands: ${INSTALL_CMDS:-none needed}. Skip gracefully if already installed.

2. BUILD + TEST: Find the correct build and test commands (check Makefile, README, package.json scripts, go.mod, Cargo.toml, pyproject.toml). Run them. Report PASS or FAIL with the key output lines (last 10 lines max). Do NOT fix failing tests — just report.

3. REFRESH CLAUDE.md: Invoke the 'bootstrap-agent-config' skill if available, else inspect the repo structure and write a grounded CLAUDE.md covering: language/runtime, build command, test command, run command, key directories, conventions. Do not overwrite if it already looks accurate — update only stale sections.

4. CODEBASE MAP: Print a concise summary titled '## Codebase map' with:
   - Main entrypoints (files / functions)
   - Key directories and what lives there
   - Exact build, test, and run commands
   - Any notable conventions or gotchas

Keep the total cost low: use Haiku for test runs and grepping, Sonnet for reasoning.
Do NOT push, force-push, merge, deploy, or delete anything."

# ── run claude ────────────────────────────────────────────────────────────────
log "running claude (sonnet · acceptEdits)"
note "this may take a few minutes …"

HAVE_JQ=0; command -v jq >/dev/null 2>&1 && HAVE_JQ=1
COST="0"

if [ "$HAVE_JQ" = 1 ]; then
  TMPFILE="$(mktemp /tmp/compass-onboard-XXXXXX.json)"
  # Run from the target directory so the agent's relative paths resolve correctly.
  (cd "$DIR" && claude -p "$PROMPT" \
    --model claude-sonnet-4-5 \
    --permission-mode acceptEdits \
    --allowedTools "$ALL_TOOLS" \
    --output-format json) >"$TMPFILE" 2>/dev/null || true
  # Print the result text to stdout.
  jq -r '.result // ""' "$TMPFILE" 2>/dev/null || true
  COST="$(jq -r '.total_cost_usd // 0' "$TMPFILE" 2>/dev/null || echo 0)"
  rm -f "$TMPFILE"
else
  (cd "$DIR" && claude -p "$PROMPT" \
    --model claude-sonnet-4-5 \
    --permission-mode acceptEdits \
    --allowedTools "$ALL_TOOLS" \
    --output-format text) || true
fi

# ── spend ledger ──────────────────────────────────────────────────────────────
COMPASS_HOME="${COMPASS_HOME:-$HOME/.compass}"
mkdir -p "$COMPASS_HOME"
LEDGER="$COMPASS_HOME/spend.tsv"
if [ ! -f "$LEDGER" ]; then
  touch "$LEDGER"
fi
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\t%s\t%s\t%s\t%s\n' "$TIMESTAMP" "$REPO_NAME" "onboard" "sonnet" "$COST" >>"$LEDGER"

ok "logged to spend ledger: $LEDGER"
printf '  %sCost this run:%s $%s\n' "$C_BOLD" "$C_RST" "$COST"
printf '\n%sOnboarding complete.%s\n' "$C_GREEN" "$C_RST"
