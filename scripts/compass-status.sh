#!/usr/bin/env bash
# compass-status.sh — "is compass enabled here?" Run from any repo. Reports the GLOBAL config
# (which makes every repo compass-enabled) and this repo's optional per-repo extras.
set -euo pipefail

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; V=$'\033[38;5;141m'; X=$'\033[0m'
else B=""; D=""; G=""; Y=""; R=""; V=""; X=""; fi
yes_()   { printf '  %s✓%s %s\n' "$G" "$X" "$*"; }
nope_()  { printf '  %s✗%s %s\n' "$R" "$X" "$*"; }
maybe_() { printf '  %s•%s %s\n' "$Y" "$X" "$*"; }

DIR="${1:-$PWD}"
printf '\n%s🧭 compass · status%s  %s%s%s\n' "$V" "$X" "$D" "$DIR" "$X"
printf '%s──────────────────────────────────────────%s\n' "$D" "$X"

printf '%sGlobal — applies to EVERY repo%s\n' "$B" "$X"
gl="$HOME/.claude/CLAUDE.md"
if [ -L "$gl" ]; then
  repo="$(readlink "$gl")"; repo="${repo%/claude/CLAUDE.md}"
  yes_ "operating manual + guardrails + subagents + commands  ${D}→ ${repo}${X}"
elif [ -e "$gl" ]; then maybe_ "~/.claude/CLAUDE.md exists but isn't a compass symlink"
else nope_ "not installed — run ${B}make install${X} from the compass repo"; fi
if [ -L "$HOME/.claude/hooks" ]; then yes_ "guardrail + format hooks (block disasters, auto-format edits)"; else maybe_ "hooks not linked"; fi
if command -v compass >/dev/null 2>&1; then yes_ "compass CLI on PATH  ${D}($(command -v compass))${X}"
else maybe_ "compass CLI not on PATH yet (open a new shell after install)"; fi

printf '\n%sThis repo — optional per-repo extras%s\n' "$B" "$X"
if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  root="$(git -C "$DIR" rev-parse --show-toplevel)"
  yes_ "git repo  ${D}($(basename "$root"))${X}"
  [ -f "$root/CLAUDE.md" ] && yes_ "committed CLAUDE.md (per-repo context)" \
    || maybe_ "no committed CLAUDE.md  ${D}— optional: compass onboard · make new-repo${X}"
  [ -L "$root/AGENTS.md" ] && yes_ "AGENTS.md → CLAUDE.md (cross-tool)" \
    || maybe_ "no AGENTS.md symlink  ${D}— optional${X}"
  if compgen -G "$root/.github/workflows/sdlc-"'*.yml' >/dev/null 2>&1; then
    n="$(find "$root/.github/workflows" -name 'sdlc-*.yml' 2>/dev/null | wc -l | tr -d ' ')"
    yes_ "autonomous SDLC loop installed  ${D}($n workflows)${X}"
  else maybe_ "autonomous SDLC loop not installed  ${D}— optional: sdlc/setup.sh --all${X}"; fi
else maybe_ "not a git repo — the global config still applies"; fi

printf '\n%sBottom line:%s ' "$B" "$X"
if [ -L "$gl" ]; then
  printf '%scompass is enabled here%s — the global config applies to this and every repo.\n\n' "$G" "$X"
else
  printf '%scompass is NOT installed%s — run %smake install%s from the compass repo.\n\n' "$R" "$X" "$B" "$X"
fi
