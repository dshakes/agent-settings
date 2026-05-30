#!/usr/bin/env bash
# Helpers for demo.tape so the *recorded* commands stay short, clean, and COLORFUL
# (no raw JSON on screen). Sourced from the repo root in the tape's hidden setup.
H="claude/hooks/protect-paths.sh"
R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; P=$'\033[35m'; D=$'\033[90m'; B=$'\033[1m'; X=$'\033[0m'

guard() {  # guard '<command>' -> red BLOCKED / green allowed (no JSON)
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | "$H" >/dev/null 2>&1
  if [ $? -eq 2 ]; then printf "  %b%-18s%b  %b●  BLOCKED%b\n" "$B" "$1" "$X" "$R" "$X"
  else printf "  %b%-18s%b  %b●  allowed%b\n" "$B" "$1" "$X" "$G" "$X"; fi
}

statusline() {
  printf '{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"/Users/you/myrepo"},"permission_mode":"acceptEdits","cost":{"estimated_cost_cents":37,"total_input_tokens":42000}}' \
    | claude/statusline.sh; echo
}

# The autonomous PR loop, as a quick colored sequence.
loop() {
  printf "  %byou open a PR%b\n" "$D" "$X"
  sleep 0.5; printf "    review · security · tests · %bCodex audit%b\n" "$P" "$X"
  sleep 0.6; printf "    %b●  BLOCKING%b  → Builder fixes on the branch ↻ re-review\n" "$R" "$X"
  sleep 0.7; printf "    %b●  CLEAN%b     → checks green\n" "$G" "$X"
  sleep 0.5; printf "  %b✓ you merge%b   %b(humans own merge & deploy — always)%b\n" "$G$B" "$X" "$D" "$X"
}

crew() {
  printf "  %b9 subagents%b  architect·reviewer·%bsecurity%b·debugger·go/rust·k8s·qa·docs\n" "$B" "$X" "$P" "$X"
  printf "  %b11 commands%b  /ship /review /tdd /spec /pr /adr /triage /scaffold /cost\n" "$B" "$X"
}
