#!/usr/bin/env bash
# common.sh — shared helpers for Claude Code hooks.
# Sourced by every hook. Must never exit non-zero on its own.
#
# Design goals:
#   - Zero hard dependencies. Prefer jq, fall back to python3, then to grep/sed.
#   - Never break a session: helpers degrade gracefully and stay quiet on error.
#   - Fast: hooks run on the hot path of every tool call.

set -o pipefail

# Read a string field from a JSON document.
#   json_get '<json>' '.tool_name'
#   json_get '<json>' '.tool_input.command'
# Prints the value (empty string if missing). Never fails the caller.
json_get() {
  local json="$1" path="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r "$path // empty" 2>/dev/null
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$json" | python3 -c '
import sys, json
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(0)
path = sys.argv[1].lstrip(".").split(".")
cur = doc
for key in path:
    if isinstance(cur, dict) and key in cur:
        cur = cur[key]
    else:
        sys.exit(0)
if cur is None:
    sys.exit(0)
print(cur if isinstance(cur, str) else json.dumps(cur))
' "$path" 2>/dev/null
    return 0
  fi
  # Last-resort: shallow scalar extraction for top-level keys like .tool_name
  local key="${path##*.}"
  printf '%s' "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"\(.*\)"/\1/'
}

# Emit a PreToolUse deny decision (stdout JSON) and exit 2 (block).
# Usage: deny "human-readable reason"
deny() {
  local reason="$1"
  cat <<JSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$(json_string "$reason")}}
JSON
  exit 2
}

# Emit additional context for the model (UserPromptSubmit / SessionStart) and exit 0.
emit_context() {
  local ctx="$1" event="${2:-UserPromptSubmit}"
  cat <<JSON
{"hookSpecificOutput":{"hookEventName":"$event","additionalContext":$(json_string "$ctx")}}
JSON
  exit 0
}

# JSON-encode a string safely (quotes included).
json_string() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -Rs .
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$1" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))'
  else
    # Minimal escaping fallback.
    local s="$1"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"
    printf '"%s"' "$s"
  fi
}

# True if a command exists.
have() { command -v "$1" >/dev/null 2>&1; }
