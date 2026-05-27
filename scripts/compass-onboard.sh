#!/usr/bin/env bash
# compass-onboard.sh — onboard an engineer into a local repo (or many).
#
# One repo: detect stack → install deps → build+test → grounded CLAUDE.md → codebase map,
# via ONE budget-capped `claude -p`. Logs cost to the spend ledger.
#
#   compass onboard [--dry-run] [DIR]                 # one repo (default ".")
#   compass onboard --all [--force] [--yes] <glob>... # many repos: lists, estimates, confirms,
#                                                       # runs sequentially, skips already-onboarded
# Env: COMPASS_ONBOARD_BUDGET (USD per repo, default 1.50)
set -euo pipefail

C_RST=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
C_CYAN=$'\033[38;5;39m'; C_GREEN=$'\033[38;5;42m'; C_AMBER=$'\033[38;5;214m'
C_RED=$'\033[38;5;196m'; C_VIOLET=$'\033[38;5;141m'
log()  { printf '\n%s▶ %s%s\n' "$C_CYAN" "$*" "$C_RST"; }
note() { printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RST"; }
ok()   { printf '  %s✓ %s%s\n' "$C_GREEN" "$*" "$C_RST"; }
err()  { printf '%sERROR: %s%s\n' "$C_RED" "$*" "$C_RST" >&2; }

DRY_RUN=0; ALL=0; FORCE=0; YES=0; DIRS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --all)     ALL=1 ;;
    --force)   FORCE=1 ;;
    --yes|-y)  YES=1 ;;
    --help|-h)
      printf '%sUsage:%s compass onboard [--dry-run] [DIR]\n' "$C_BOLD" "$C_RST"
      printf '       compass onboard --all [--force] [--yes] <dir|glob>...\n'
      printf '  Detect stack, install deps, build+test, write CLAUDE.md, print a codebase map.\n'
      printf '  --all      Onboard many repos (git repos only); skips ones that already have a CLAUDE.md.\n'
      printf '  --force    With --all, re-onboard even if CLAUDE.md exists.\n'
      printf '  --yes      Skip the confirmation prompt (required when non-interactive).\n'
      printf '  --dry-run  Show the plan; do nothing effectful.\n'
      printf '  Env: COMPASS_ONBOARD_BUDGET (USD/repo, default 1.50).\n'
      exit 0 ;;
    -*) err "unknown flag: $a  (try --help)"; exit 2 ;;
    *)  DIRS+=("$a") ;;
  esac
done

ONBOARD_BUDGET="${COMPASS_ONBOARD_BUDGET:-1.50}"
COMPASS_HOME="${COMPASS_HOME:-$HOME/.compass}"

# detect_stack <dir> — sets STACKS / INSTALL_CMDS / ALLOWED_BASH_TOOLS (globals).
detect_stack() {
  local DIR="$1" f PY_REQ=""
  STACKS=""; INSTALL_CMDS=""; ALLOWED_BASH_TOOLS=""
  if [ -f "$DIR/go.mod" ]; then
    STACKS="${STACKS:+$STACKS, }Go"; INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }go mod download"
    ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(go mod download:*),Bash(go build:*),Bash(go test:*),Bash(go vet:*)"
  fi
  if [ -f "$DIR/package.json" ]; then
    local pm="npm"; [ -f "$DIR/pnpm-lock.yaml" ] && pm="pnpm"; [ -f "$DIR/yarn.lock" ] && pm="yarn"
    STACKS="${STACKS:+$STACKS, }Node (${pm})"; INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }${pm} install"
    ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(${pm}:*),Bash(npx tsc:*)"
  fi
  if [ -f "$DIR/Cargo.toml" ]; then
    STACKS="${STACKS:+$STACKS, }Rust"; INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }cargo fetch"
    ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(cargo build:*),Bash(cargo test:*),Bash(cargo clippy:*),Bash(cargo fetch:*)"
  fi
  for f in "$DIR"/requirements*.txt; do [ -f "$f" ] && { PY_REQ="$f"; break; }; done
  if [ -f "$DIR/pyproject.toml" ] || [ -f "$DIR/setup.py" ] || [ -f "$DIR/setup.cfg" ] \
     || [ -f "$DIR/Pipfile" ] || [ -n "$PY_REQ" ] || compgen -G "$DIR/*.py" >/dev/null 2>&1; then
    STACKS="${STACKS:+$STACKS, }Python"
    if [ -f "$DIR/pyproject.toml" ]; then INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }uv sync 2>/dev/null || pip install -e ."
    elif [ -n "$PY_REQ" ]; then INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }pip install -r $(basename "$PY_REQ")"
    else INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }pip install -e . 2>/dev/null || true"; fi
    ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(uv:*),Bash(pip:*),Bash(pytest:*),Bash(ruff:*),Bash(python:*),Bash(python3:*)"
  fi
  if [ -f "$DIR/mix.exs" ]; then
    STACKS="${STACKS:+$STACKS, }Elixir"; INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }mix deps.get"
    ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(mix:*)"
  fi
  if [ -f "$DIR/Gemfile" ]; then
    STACKS="${STACKS:+$STACKS, }Ruby"; INSTALL_CMDS="${INSTALL_CMDS:+$INSTALL_CMDS; }bundle install"
    ALLOWED_BASH_TOOLS="${ALLOWED_BASH_TOOLS:+$ALLOWED_BASH_TOOLS,}Bash(bundle:*),Bash(ruby:*),Bash(rake:*)"
  fi
  [ -n "$STACKS" ] || STACKS="(unknown — no recognised manifest found)"
}

# onboard_one <dir> — detect, plan, and (unless --dry-run) run one budget-capped claude pass.
onboard_one() {
  local DIR REPO_NAME
  DIR="$(cd "$1" && pwd)"; REPO_NAME="$(basename "$DIR")"
  printf '\n%scompass · onboard%s  %s\n' "$C_VIOLET" "$C_RST" "$DIR"
  log "detecting stack"; detect_stack "$DIR"
  printf '  %sDetected stack:%s %s\n' "$C_BOLD" "$C_RST" "$STACKS"
  log "plan"
  note "1. Install dependencies  (${INSTALL_CMDS:-none needed})"
  note "2. Find + run build and test commands; report pass/fail"
  note "3. Write or refresh CLAUDE.md via the bootstrap-agent-config skill"
  note "4. Print a codebase map: entrypoints, key directories, build/test/run commands"
  if [ "$DRY_RUN" = 1 ]; then printf '\n%s--dry-run: stopping here.%s\n' "$C_AMBER" "$C_RST"; return 0; fi
  if ! command -v claude >/dev/null 2>&1; then
    err "claude CLI not found on PATH — https://docs.anthropic.com/en/docs/claude-code/getting-started"; return 1
  fi
  local base_tools all_tools
  base_tools="Read,Edit,Write,Grep,Glob,Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(make:*)"
  all_tools="$base_tools"; [ -n "$ALLOWED_BASH_TOOLS" ] && all_tools="${base_tools},${ALLOWED_BASH_TOOLS}"
  local prompt
  prompt="You are onboarding an engineer into the repo at: $DIR
Detected stack: $STACKS

Do these four things IN ORDER — delegate mechanical steps to cheap subagents to keep cost low:
1. INSTALL DEPS for the detected stack (${INSTALL_CMDS:-none needed}). Skip gracefully if already installed.
2. BUILD + TEST: find the real build and test commands (Makefile, README, package.json scripts, go.mod, Cargo.toml, pyproject.toml), run them, report PASS/FAIL with the last ~10 output lines. Do NOT fix failures — just report.
3. REFRESH CLAUDE.md: invoke the 'bootstrap-agent-config' skill if available, else write a grounded CLAUDE.md (language, build/test/run commands, key dirs, conventions). Update only stale sections.
4. CODEBASE MAP: print '## Codebase map' with entrypoints, key directories, exact build/test/run commands, and notable gotchas.
Keep cost low (Haiku for test runs + grepping). Do NOT push, force-push, merge, deploy, or delete anything."

  log "running claude (sonnet · acceptEdits · budget \$$ONBOARD_BUDGET)"
  note "this may take a few minutes …"
  local cost="0"
  if command -v jq >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp)"
    (cd "$DIR" && claude -p "$prompt" --model sonnet --permission-mode acceptEdits \
      --allowedTools "$all_tools" --max-turns 30 --max-budget-usd "$ONBOARD_BUDGET" \
      --output-format json) >"$tmp" 2>/dev/null || true
    jq -r '.result // ""' "$tmp" 2>/dev/null || true
    cost="$(jq -r '.total_cost_usd // 0' "$tmp" 2>/dev/null || echo 0)"
    rm -f "$tmp"
  else
    (cd "$DIR" && claude -p "$prompt" --model sonnet --permission-mode acceptEdits \
      --allowedTools "$all_tools" --max-turns 30 --max-budget-usd "$ONBOARD_BUDGET" \
      --output-format text) || true
  fi
  mkdir -p "$COMPASS_HOME"
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$REPO_NAME" "onboard" "sonnet" "$cost" >>"$COMPASS_HOME/spend.tsv"
  ok "onboarded $REPO_NAME — cost \$$cost (logged to spend ledger)"
}

if [ "$ALL" = 1 ]; then
  [ "${#DIRS[@]}" -gt 0 ] || { err "--all needs a dir/glob, e.g.  compass onboard --all ~/code/*"; exit 2; }
  repos=(); skipped=0
  for d in "${DIRS[@]}"; do
    [ -d "$d" ] || continue
    git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
    if [ "$FORCE" = 0 ] && [ -f "$d/CLAUDE.md" ]; then skipped=$((skipped + 1)); continue; fi
    repos+=("$(cd "$d" && pwd)")
  done
  printf '\n%scompass · onboard --all%s\n' "$C_VIOLET" "$C_RST"
  note "$skipped repo(s) skipped (already have CLAUDE.md; use --force to redo)"
  if [ "${#repos[@]}" -eq 0 ]; then ok "nothing to onboard."; exit 0; fi
  printf '  %sWill onboard %d repo(s):%s\n' "$C_BOLD" "${#repos[@]}" "$C_RST"
  for d in "${repos[@]}"; do note "• $d"; done
  est="$(awk -v b="$ONBOARD_BUDGET" -v n="${#repos[@]}" 'BEGIN{printf "%.2f", b*n}')"
  printf '  %sEstimated max cost:%s ~\$%s  %s(%d × \$%s budget cap each)%s\n' "$C_AMBER" "$C_RST" "$est" "$C_DIM" "${#repos[@]}" "$ONBOARD_BUDGET" "$C_RST"
  if [ "$DRY_RUN" = 1 ]; then printf '\n%s--dry-run: not running.%s\n' "$C_AMBER" "$C_RST"; exit 0; fi
  if [ "$YES" = 0 ]; then
    if [ -e /dev/tty ]; then
      printf '  %sProceed? [y/N] %s' "$C_BOLD" "$C_RST"; read -r ans </dev/tty || ans=""
      case "$ans" in y|Y|yes|YES) ;; *) note "aborted."; exit 0 ;; esac
    else err "non-interactive: re-run with --yes to proceed"; exit 2; fi
  fi
  for d in "${repos[@]}"; do onboard_one "$d" || note "onboard failed for $d — continuing"; done
  printf '\n%sAll done.%s Run %scompass impact%s to see spend.\n' "$C_GREEN" "$C_RST" "$C_BOLD" "$C_RST"
else
  onboard_one "${DIRS[0]:-.}"
fi
