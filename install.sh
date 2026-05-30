#!/usr/bin/env bash
# install.sh — wire this repo into your live ~/.claude and ~/.codex.
#
# Idempotent. Backs up anything it would replace into a timestamped folder.
# Default is symlink (edit in-repo, version it, `git pull` to update everyone).
#
#   ./install.sh                  # symlink into ~/.claude and ~/.codex
#   ./install.sh --copy           # copy instead of symlink
#   ./install.sh --dry-run        # show what would happen, change nothing
#   ./install.sh --claude-only    # skip Codex
#   ./install.sh --codex-only     # skip Claude
#   ./install.sh --gemini         # ALSO feed the same manual to Gemini CLI (~/.gemini/GEMINI.md)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SRC="$REPO/claude"
CODEX_SRC="$REPO/codex"
CLAUDE_DST="$HOME/.claude"
CODEX_DST="$HOME/.codex"
GEMINI_DST="$HOME/.gemini"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.claude/backups/compass-$STAMP"

MODE="symlink"; DRY=0; DO_CLAUDE=1; DO_CODEX=1; DO_GEMINI=0; DO_CLI=1
for arg in "$@"; do
  case "$arg" in
    --copy) MODE="copy" ;;
    --dry-run) DRY=1 ;;
    --claude-only) DO_CODEX=0 ;;
    --codex-only) DO_CLAUDE=0 ;;
    --gemini) DO_GEMINI=1 ;;
    --no-cli) DO_CLI=0 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

say()  { printf '  %s\n' "$*"; }
head() { printf '\n\033[1m%s\033[0m\n' "$*"; }
run()  { if [ "$DRY" = 1 ]; then say "[dry-run] $*"; else eval "$*"; fi; }

# Link or copy SRC -> DST, backing up an existing real DST first.
place() {
  local src="$1" dst="$2"
  [ -e "$src" ] || { say "skip (missing): $src"; return; }
  if [ -L "$dst" ]; then run "rm -f '$dst'"; fi          # replace stale symlink
  if [ -e "$dst" ]; then
    run "mkdir -p '$BACKUP/$(dirname "${dst#$HOME/}")'"
    run "mv '$dst' '$BACKUP/${dst#$HOME/}'"
    say "backed up: ${dst#$HOME/}"
  fi
  run "mkdir -p '$(dirname "$dst")'"
  if [ "$MODE" = "symlink" ]; then run "ln -s '$src' '$dst'"; say "linked: ${dst#$HOME/} -> ${src#$REPO/}"
  else run "cp -R '$src' '$dst'"; say "copied: ${dst#$HOME/}"; fi
}

chmodx() { [ "$DRY" = 1 ] && return; find "$1" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true; }

# Bake the `compass` CLI onto PATH: symlink into ~/.local/bin (repo-location-independent)
# and, if that dir isn't on PATH, add it to the shell rc once (marker-tagged for clean removal).
install_cli() {
  local bindir="$HOME/.local/bin" src="$REPO/bin/compass" dst
  dst="$bindir/compass"
  head "compass CLI  →  $dst"
  run "mkdir -p '$bindir'"
  chmodx "$REPO/scripts"; [ "$DRY" = 1 ] || chmod +x "$src" 2>/dev/null || true
  if [ -L "$dst" ]; then run "rm -f '$dst'"; fi
  if [ -e "$dst" ]; then run "mkdir -p '$BACKUP'"; run "mv '$dst' '$BACKUP/compass'"; say "backed up: ~/.local/bin/compass"; fi
  run "ln -s '$src' '$dst'"; say "linked: ~/.local/bin/compass -> ${src#$REPO/}"
  case ":$PATH:" in
    *":$bindir:"*) say "~/.local/bin already on PATH ✓  — try: compass impact" ;;
    *)
      local rc=""
      case "${SHELL##*/}" in
        zsh)  rc="$HOME/.zshrc" ;;
        bash) rc="$HOME/.bash_profile"; [ -f "$HOME/.bashrc" ] && rc="$HOME/.bashrc" ;;
      esac
      if [ -n "$rc" ] && [ "$DRY" = 0 ]; then
        if grep -q 'compass CLI on PATH' "$rc" 2>/dev/null; then say "PATH line already in ${rc#$HOME/}"
        else printf '\n# compass CLI on PATH (added by compass install)\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$rc"
          say "added ~/.local/bin to PATH in ${rc#$HOME/} — run: source ${rc#$HOME/}"; fi
      else say "add ~/.local/bin to your PATH, then: compass impact"; fi ;;
  esac
}

# Codex config is precious (plugins, marketplaces, trusted projects). Never
# clobber it: if it exists, append our cost profiles once (marker-delimited,
# inert until `--profile` is used). Only symlink the full template when absent.
MARK_BEGIN="# >>> compass profiles >>>"
MARK_END="# <<< compass profiles <<<"
merge_codex_profiles() {
  local dst="$1"
  if [ ! -e "$dst" ]; then place "$CODEX_SRC/config.toml" "$dst"; return; fi
  if grep -qF "$MARK_BEGIN" "$dst" 2>/dev/null; then say "profiles already present: ${dst#$HOME/}"; return; fi
  say "appending cost profiles to existing config (preserving plugins/projects): ${dst#$HOME/}"
  [ "$DRY" = 1 ] && return
  cat >>"$dst" <<TOML

$MARK_BEGIN
# Cost/quality tiers — parity with the Claude subagent model tiers.
# Use with: codex --profile {deep|standard|cheap}. Inert otherwise.
[profiles.deep]
model_reasoning_effort = "xhigh"
approval_policy = "on-request"

[profiles.standard]
model_reasoning_effort = "high"
approval_policy = "on-request"

[profiles.cheap]
model_reasoning_effort = "low"
approval_policy = "on-failure"
$MARK_END
TOML
}

head "compass installer  (mode: $MODE$( [ "$DRY" = 1 ] && printf ', dry-run' ))"
say "repo:   $REPO"

if [ "$DO_CLAUDE" = 1 ]; then
  head "Claude Code  →  $CLAUDE_DST"
  run "mkdir -p '$CLAUDE_DST'"
  place "$CLAUDE_SRC/settings.json"   "$CLAUDE_DST/settings.json"
  place "$CLAUDE_SRC/CLAUDE.md"       "$CLAUDE_DST/CLAUDE.md"
  place "$CLAUDE_SRC/statusline.sh"   "$CLAUDE_DST/statusline.sh"
  place "$CLAUDE_SRC/agents"          "$CLAUDE_DST/agents"
  place "$CLAUDE_SRC/commands"        "$CLAUDE_DST/commands"
  place "$CLAUDE_SRC/skills"          "$CLAUDE_DST/skills"
  place "$CLAUDE_SRC/workflows"       "$CLAUDE_DST/workflows"
  place "$CLAUDE_SRC/hooks"           "$CLAUDE_DST/hooks"
  place "$CLAUDE_SRC/output-styles"   "$CLAUDE_DST/output-styles"
  chmodx "$CLAUDE_SRC/hooks"; chmodx "$CLAUDE_SRC/skills"
  [ "$DRY" = 1 ] || chmod +x "$CLAUDE_SRC/statusline.sh" 2>/dev/null || true
fi

if [ "$DO_CODEX" = 1 ]; then
  head "Codex  →  $CODEX_DST"
  run "mkdir -p '$CODEX_DST'"
  merge_codex_profiles "$CODEX_DST/config.toml"   # never clobbers an existing config
  place "$CODEX_SRC/AGENTS.md" "$CODEX_DST/AGENTS.md"
fi

if [ "$DO_GEMINI" = 1 ]; then
  head "Gemini CLI  →  $GEMINI_DST"
  run "mkdir -p '$GEMINI_DST'"
  # Same operating manual, one source. Gemini CLI reads ~/.gemini/GEMINI.md by default.
  place "$CLAUDE_SRC/CLAUDE.md" "$GEMINI_DST/GEMINI.md"
  say "tip: to also use per-repo AGENTS.md in Gemini, set context.fileName in ~/.gemini/settings.json:"
  say '      { "context": { "fileName": ["AGENTS.md", "GEMINI.md"] } }'
fi

[ "$DO_CLI" = 1 ] && install_cli

head "Done."
[ -d "$BACKUP" ] && say "Backups of anything replaced: $BACKUP"
say "Next: open Claude Code and run /agents, /status, and /doctor to confirm."
say "      Validate config anytime with:  make doctor"
