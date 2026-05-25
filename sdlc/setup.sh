#!/usr/bin/env bash
# setup.sh — onboard a repo to the compass SDLC pipeline. Run from the repo root.
#
# Most automated (one command does everything):
#   ~/compass/sdlc/setup.sh --all
#     → labels + workflows + CODEOWNERS + commit/push + secrets + branch protection
#
# Composable flags (pick what you want):
#   --workflows   copy sdlc workflows + CODEOWNERS into .github/
#   --commit      git add .github && commit && push
#   --secrets     set ANTHROPIC_API_KEY / OPENAI_API_KEY (from env if exported, else prompt)
#   --protect     apply branch protection on the default branch (the human merge gate)
#   --all         all of the above
#
# Secrets: export them first for zero prompts:  export ANTHROPIC_API_KEY=… OPENAI_API_KEY=…
set -euo pipefail
SDLC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WF=0 COMMIT=0 SECRETS=0 PROTECT=0 SELF=0
for a in "$@"; do case "$a" in
  --workflows) WF=1 ;; --commit) COMMIT=1 ;; --secrets) SECRETS=1 ;; --protect) PROTECT=1 ;;
  --self-hosted) WF=1; SELF=1 ;;          # keyless: claude -p / codex exec on a self-hosted runner
  --all) WF=1; COMMIT=1; SECRETS=1; PROTECT=1 ;;
  *) echo "unknown flag: $a"; exit 2 ;;
esac; done

command -v gh >/dev/null || { echo "gh CLI required"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "run inside the target repo"; exit 1; }
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
BRANCH="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
echo "==> $REPO  (default branch: $BRANCH)"

echo "==> Labels"
python3 - "$SDLC_DIR/labels.yml" <<'PY' | while IFS=$'\t' read -r name color desc; do
import sys, re
for blk in open(sys.argv[1]).read().split("- name:")[1:]:
    print("\t".join([re.search(r'"([^"]+)"',blk).group(1),
                     re.search(r'color:\s*"([^"]+)"',blk).group(1),
                     re.search(r'description:\s*"([^"]+)"',blk).group(1)]))
PY
  gh label create "$name" --color "$color" --description "$desc" --force >/dev/null && echo "  ✓ $name"
done

if [ "$WF" = 1 ]; then
  SRC_WF="$SDLC_DIR/workflows"; [ "$SELF" = 1 ] && SRC_WF="$SDLC_DIR/selfhosted"
  echo "==> Workflows + CODEOWNERS  ($([ "$SELF" = 1 ] && echo 'self-hosted · keyless (claude -p / codex exec)' || echo 'hosted · Action'))"
  mkdir -p .github/workflows
  cp "$SRC_WF"/*.yml .github/workflows/ && echo "  ✓ .github/workflows/sdlc-*.yml"
  [ -f .github/CODEOWNERS ] || { cp "$SDLC_DIR/CODEOWNERS.sample" .github/CODEOWNERS && echo "  ✓ .github/CODEOWNERS (edit owners)"; }
  [ "$SELF" = 1 ] && echo "  → register a runner with label 'compass' (see sdlc/selfhosted/README.md); no secrets needed."
fi

if [ "$COMMIT" = 1 ]; then
  echo "==> Commit + push wiring"
  git add .github 2>/dev/null || true
  if git diff --cached --quiet; then echo "  · nothing to commit"
  else git commit -q -m "ci: install compass SDLC workflows + CODEOWNERS" && git push -q && echo "  ✓ pushed"; fi
fi

if [ "$SECRETS" = 1 ]; then
  echo "==> Secrets"
  set_secret(){ local n="$1" v="${!1:-}"
    if [ -n "$v" ]; then printf '%s' "$v" | gh secret set "$n" >/dev/null && echo "  ✓ $n (from env)"
    else echo "  · $n not exported — skipped (set later: gh secret set $n)"; fi; }
  set_secret CLAUDE_CODE_OAUTH_TOKEN   # preferred: subscription token (claude setup-token), no API credits
  set_secret ANTHROPIC_API_KEY         # alternative: pay-per-use API key
  set_secret OPENAI_API_KEY            # Codex cloud audit
  set_secret SDLC_BOT_TOKEN            # PAT that lets the fix loop chain (see note below)
  [ -n "${SDLC_BOT_TOKEN:-}" ] || cat <<'BOT'
  ┌ SDLC_BOT_TOKEN not set. The auto-fix LOOP needs it: GitHub will not let a push made
  │ with the default token re-trigger the Reviewer. Create a fine-grained PAT (Contents:
  │ write, Pull requests: write on this repo), then:  gh secret set SDLC_BOT_TOKEN
  └ Without it, review/fix still run once each, but won't auto-loop (degrades to manual).
BOT
fi

if [ "$PROTECT" = 1 ]; then
  echo "==> Branch protection on '$BRANCH' (the human merge gate)"
  # Require the agent checks 'review' (red on Blocking findings) + 'qa' (red on test fail)
  # to be green, plus a PR with 1 code-owner approval. strict:false so a PR need not be
  # rebased onto every base push. Remove a context here if your repo doesn't run it.
  gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" --input - >/dev/null <<JSON && echo "  ✓ require PR + 1 approval + code-owner review + checks [review, qa]; no bypass" || echo "  ! protection failed (need admin?)"
{ "required_status_checks": { "strict": false, "contexts": ["review", "qa"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 1, "require_code_owner_reviews": true },
  "restrictions": null }
JSON
fi

cat <<NEXT

==> Ready. Remaining (one-time, manual — deploy gate):
  Settings → Environments → 'production' → Required reviewers (gates deploy).
The closed loop (needs SDLC_BOT_TOKEN to auto-chain):
  open a PR → Reviewer + Security + QA + Codex audit run → if the Reviewer finds Blocking
  issues it labels 'agent:needs-fix' → Builder fixes on the PR branch + pushes → Reviewer
  re-runs → … repeats up to SDLC_MAX_FIX_ROUNDS (default 3) → then 'sdlc:needs-human'.
  You still merge & deploy.
On demand:  label 'agent:audit' (re-audit) · 'agent:release' (release prep) ·
  comment '@claude <task>' (ad-hoc build) · label an issue 'agent:plan' (triage→plan).
Local headless run:  ~/compass/sdlc/orchestrate.sh "your task"
NEXT
