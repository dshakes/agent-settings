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
WF=0 COMMIT=0 SECRETS=0 PROTECT=0
for a in "$@"; do case "$a" in
  --workflows) WF=1 ;; --commit) COMMIT=1 ;; --secrets) SECRETS=1 ;; --protect) PROTECT=1 ;;
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
  echo "==> Workflows + CODEOWNERS"
  mkdir -p .github/workflows
  cp "$SDLC_DIR"/workflows/*.yml .github/workflows/ && echo "  ✓ .github/workflows/sdlc-*.yml"
  [ -f .github/CODEOWNERS ] || { cp "$SDLC_DIR/CODEOWNERS.sample" .github/CODEOWNERS && echo "  ✓ .github/CODEOWNERS (edit owners)"; }
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
fi

if [ "$PROTECT" = 1 ]; then
  echo "==> Branch protection on '$BRANCH' (the human merge gate)"
  gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" --input - >/dev/null <<JSON && echo "  ✓ require PR + 1 approval + code-owner review; no bypass" || echo "  ! protection failed (need admin?)"
{ "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 1, "require_code_owner_reviews": true },
  "restrictions": null }
JSON
fi

cat <<NEXT

==> Ready. Remaining (one-time, manual — deploy gate):
  Settings → Environments → 'production' → Required reviewers (gates deploy).
Use it:
  open a PR → Reviewer (Claude) runs · add label 'agent:audit' → Codex cross-audit ·
  comment '@claude <task>' → Builder implements + opens a PR.
Local headless run:  ~/compass/sdlc/orchestrate.sh "your task"
NEXT
