#!/usr/bin/env bash
# Helpers for demo.tape so the *recorded* commands stay short and clean
# (no raw JSON on screen). Sourced from the repo root in the tape's hidden setup.
H="claude/hooks/protect-paths.sh"

guard() {  # guard '<command>' -> shows BLOCKED/allowed without printing the JSON
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | "$H" >/dev/null 2>&1
  [ $? -eq 2 ] && printf '  %-16s →  BLOCKED  (exit 2)\n' "$1" \
               || printf '  %-16s →  allowed  (exit 0)\n' "$1"
}

statusline() {
  printf '{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"/Users/you/lantern"},"permission_mode":"acceptEdits","cost":{"estimated_cost_cents":37,"total_input_tokens":42000}}' \
    | claude/statusline.sh; echo
}

roster() {
  printf '  architect · code-reviewer · security-auditor · debugger\n'
  printf '  go/rust-engineer · k8s-operator · test-runner · docs-writer\n'
}
cmds()   { printf '  /ship  /review  /tdd  /pr  /adr  /triage  /scaffold  /cost\n'; }
