#!/usr/bin/env bash
# setup.sh — one-time SDLC setup for a target repo (run from the repo root).
# Creates governance labels, drops in the workflows + CODEOWNERS, and prints the
# branch-protection steps that form the human merge gate.
#
#   ~/compass/sdlc/setup.sh            # interactive summary + label creation
#   ~/compass/sdlc/setup.sh --workflows  # also copy workflows + CODEOWNERS into .github/
set -euo pipefail
SDLC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WANT_WF=0; [ "${1:-}" = "--workflows" ] && WANT_WF=1

command -v gh >/dev/null || { echo "gh CLI required"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "run inside the target repo"; exit 1; }

echo "==> Creating governance labels"
python3 - "$SDLC_DIR/labels.yml" <<'PY' | while IFS=$'\t' read -r name color desc; do
import sys, re
for blk in open(sys.argv[1]).read().split("- name:")[1:]:
    name=re.search(r'"([^"]+)"', blk).group(1)
    color=re.search(r'color:\s*"([^"]+)"', blk).group(1)
    desc=re.search(r'description:\s*"([^"]+)"', blk).group(1)
    print(f"{name}\t{color}\t{desc}")
PY
  gh label create "$name" --color "$color" --description "$desc" --force >/dev/null && echo "  ✓ $name"
done

if [ "$WANT_WF" = 1 ]; then
  echo "==> Installing workflows + CODEOWNERS"
  mkdir -p .github/workflows
  cp "$SDLC_DIR"/workflows/*.yml .github/workflows/ && echo "  ✓ .github/workflows/sdlc-*.yml"
  [ -f .github/CODEOWNERS ] || { cp "$SDLC_DIR/CODEOWNERS.sample" .github/CODEOWNERS && echo "  ✓ .github/CODEOWNERS (edit owners!)"; }
fi

cat <<'NEXT'

==> Finish the HUMAN GATE (do this in GitHub settings — agents cannot bypass it):
  1. Settings → Branches → add a rule for your default branch:
       ✓ Require a pull request before merging
       ✓ Require approvals (≥1)  +  ✓ Require review from Code Owners
       ✓ Require status checks to pass  (add the CI + review jobs)
       ✓ Do not allow bypassing the above settings
  2. Settings → Secrets and variables → Actions: add ANTHROPIC_API_KEY and OPENAI_API_KEY.
  3. (Deploy gate) Settings → Environments → 'production' → Required reviewers.

Then: open a PR → Reviewer (Claude) runs automatically; add the `agent:audit` label to
get the Codex cross-audit; comment `@claude <task>` to have Builder implement + open a PR.
Local pipeline:  ~/compass/sdlc/orchestrate.sh "your task"
NEXT
