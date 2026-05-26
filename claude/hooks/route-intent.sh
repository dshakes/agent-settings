#!/usr/bin/env bash
# route-intent.sh — UserPromptSubmit policy hook. OPT-IN (not wired by default).
#
# Detects load-bearing intent in your prompt and injects a nudge toward the right ritual
# (ADR, security pass, spec). Advisory: it injects CONTEXT, never blocks. CLAUDE.md advises;
# a hook is the only thing that fires deterministically every time — that's the point.
#
# Enable: add to settings.json under hooks.UserPromptSubmit (see docs/10-roadmap.md §8).
# Must never fail the session.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

INPUT="$(cat)"
PROMPT="$(json_get "$INPUT" '.prompt')"
low="$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')"

hint=""
case "$low" in
  *migrat*|*"schema change"*|*"new language"*|*"trust boundary"*|*"breaking change"*|*"new dependency"*|*deprecat*)
    hint="this looks load-bearing — consider an ADR first (/adr) before implementing." ;;
esac
case "$low" in
  *security*|*auth*|*secret*|*tenant*|*injection*)
    hint="${hint:+$hint }it touches security — plan a security-auditor pass on the diff." ;;
esac
case "$low" in
  *"new feature"*|*"build a"*|*"implement a"*|*"add a"*)
    hint="${hint:+$hint }for non-trivial features, a quick /spec (intent + acceptance criteria) makes the loop verify against intent." ;;
esac

[ -n "$hint" ] && emit_context "compass route-intent: $hint"
exit 0
