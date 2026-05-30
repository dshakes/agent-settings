#!/usr/bin/env bash
# protect-paths.sh — PreToolUse guardrail.
#
# Blocks the small set of actions that are almost never intended and are
# expensive to undo: writing secrets, catastrophic shell commands, and
# force-pushing/hard-resetting shared branches. Everything else is allowed
# to flow through to normal permission rules.
#
# Wired in settings.json as a PreToolUse hook matching "Bash|Edit|Write|NotebookEdit".
# Contract: exit 2 + JSON deny  => blocked. exit 0 => defer to normal rules.
#
# NOTE: this is BEST-EFFORT footgun-prevention, NOT a security boundary. It catches common
# accidents, not a determined attacker or a cleverly-obfuscated command. Keep least-privilege
# credentials and review diffs. (See SECURITY.md.)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

INPUT="$(cat)"
TOOL="$(json_get "$INPUT" '.tool_name')"

# --- File-writing tools: protect secrets and out-of-tree paths -------------
case "$TOOL" in
  Edit|Write|NotebookEdit|MultiEdit)
    FILE="$(json_get "$INPUT" '.tool_input.file_path')"
    [ -z "$FILE" ] && FILE="$(json_get "$INPUT" '.tool_input.notebook_path')"
    base="$(basename "$FILE")"
    case "$base" in
      .env|.env.*|*.pem|*.key|id_rsa|id_ed25519|*.p12|*.pfx|credentials|.npmrc|.pypirc)
        deny "Refusing to write secret-bearing file '$base'. If this is intentional, edit it yourself or use 'ask' permission." ;;
    esac
    case "$FILE" in
      */.ssh/*|*/.gnupg/*|*/.aws/credentials|*/.kube/config)
        deny "Refusing to write to a credential store ($FILE)." ;;
    esac
    exit 0 ;;
esac

# --- Bash: block catastrophic / hard-to-reverse commands -------------------
if [ "$TOOL" = "Bash" ]; then
  CMD="$(json_get "$INPUT" '.tool_input.command')"
  # Fail safe: only when NEITHER jq NOR python3 exists can json_get's grep fallback
  # truncate the command at an escaped quote (hiding a footgun after it). In that rare
  # case, also fold in the raw payload so the danger checks see the whole string —
  # erring toward a block (the safe direction), never toward a silent allow.
  if ! have jq && ! have python3; then CMD="$CMD $INPUT"; fi
  norm="$(printf '%s' "$CMD" | tr -s ' ')"

  # Recursive force-delete of root or home — but NOT of subpaths like /tmp/x,
  # ./build, or $HOME/project (those are legitimate). Only the catastrophic targets.
  if printf '%s' "$norm" | grep -Eq 'rm +-[a-zA-Z]*r[a-zA-Z]* +/( |$)' \
     || printf '%s' "$norm" | grep -Eq 'rm +-[a-zA-Z]*r[a-zA-Z]* +/\*' \
     || printf '%s' "$norm" | grep -Eq 'rm +-[a-zA-Z]*r[a-zA-Z]* +(~|\$HOME|\$\{HOME\})(/\**)?( |$)'; then
    deny "Blocked recursive force-delete of root or home. Narrow the target to a subdirectory if intentional."
  fi
  case "$norm" in
    *":(){"*)
      deny "Blocked what looks like a fork bomb." ;;
    *"chmod -R 777 /"*|*"chmod 777 /"*)
      deny "Blocked chmod 777 on a system path." ;;
    *"dd if="*"of=/dev/"*|*"mkfs."*)
      deny "Blocked a raw disk write (dd/mkfs)." ;;
    *"> /dev/sd"*)
      deny "Blocked a write to a raw block device." ;;
  esac

  # Piping the internet straight into a shell.
  case "$norm" in
    *"curl "*"| sh"*|*"curl "*"| bash"*|*"wget "*"| sh"*|*"wget "*"| bash"*)
      deny "Blocked 'curl|sh' style remote-execute. Download, read, then run if you trust it." ;;
  esac

  # Force-push / hard-reset on a protected branch.
  if printf '%s' "$norm" | grep -Eq 'git +push.*(--force|-f)([^a-z]|$)'; then
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    case "$branch" in
      main|master|release|production|prod)
        deny "Blocked force-push to protected branch '$branch'. Push to a feature branch and open a PR." ;;
    esac
    if printf '%s' "$norm" | grep -Eq 'git +push.*(origin +)?(main|master|production|prod)'; then
      deny "Blocked force-push targeting a protected remote branch."
    fi
  fi

  # Hard reset that discards committed work on a shared branch.
  if printf '%s' "$norm" | grep -Eq 'git +reset +--hard'; then
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    case "$branch" in
      main|master|release|production|prod)
        deny "Blocked 'git reset --hard' on protected branch '$branch'." ;;
    esac
  fi
fi

exit 0
