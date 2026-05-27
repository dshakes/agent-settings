#!/usr/bin/env bash
# smoketest-scaffold.sh — build a THROWAWAY local project to run the SDLC live smoke
# test (sdlc/SMOKETEST.md). Creates a tiny Python repo with a passing + a deliberately
# buggy branch, then prints the exact gh / setup.sh commands for you to run (push +
# watch the Actions tab). It does NOT create a remote repo, push, or touch your tokens.
set -euo pipefail

DIR="${1:-/tmp/compass-smoketest}"
COMPASS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; P=$'\033[35m'; X=$'\033[0m'
else B=""; D=""; G=""; Y=""; P=""; X=""; fi

[ -e "$DIR" ] && { echo "refusing: $DIR already exists — pass a fresh path"; exit 2; }
command -v git >/dev/null || { echo "git required"; exit 2; }

echo "${B}Scaffolding a throwaway SDLC smoke-test repo at${X} $DIR"
mkdir -p "$DIR"; cd "$DIR"
git init -q

# --- tiny, real test suite so `qa` is meaningful ---
cat > calc.py <<'PY'
def add(a, b):
    return a + b

def divide(a, b):
    if b == 0:
        raise ValueError("division by zero")
    return a / b
PY

cat > test_calc.py <<'PY'
from calc import add, divide
import pytest

def test_add():
    assert add(2, 3) == 5

def test_divide():
    assert divide(6, 2) == 3

def test_divide_by_zero():
    with pytest.raises(ValueError):
        divide(1, 0)
PY

cat > requirements-dev.txt <<'TXT'
pytest
TXT

cat > README.md <<'MD'
# compass smoke-test repo (throwaway)
A tiny project to exercise the compass autonomous SDLC loop end to end.
Delete this repo when done.
MD

git add -A; git commit -q -m "init: tiny calc + tests (all green)"
DEFAULT_BRANCH="$(git symbolic-ref --short HEAD)"

# --- a deliberately buggy branch: the headline "loop closes itself" case ---
git switch -q -c bug/off-by-one
cat > calc.py <<'PY'
def add(a, b):
    return a + b + 1   # BUG: off-by-one the Reviewer should flag (also breaks test_add)

def divide(a, b):
    return a / b        # BUG: no zero guard — drops the ValueError contract (breaks test_divide_by_zero)
PY
git add -A; git commit -q -m "feat: tweak calc (contains a bug for the agents to catch)"
git switch -q "$DEFAULT_BRANCH"

echo
echo "${G}✓ Done.${X} Local repo ready (default branch: ${B}$DEFAULT_BRANCH${X}, buggy branch: ${B}bug/off-by-one${X})."
echo
echo "${B}Now run these yourself${X} ${D}(needs: gh logged in, the Claude GitHub App, and tokens)${X}:"
echo
echo "  ${P}# 1) create a PRIVATE remote + push${X}"
echo "  cd $DIR"
echo "  gh repo create compass-smoketest --private --source=. --remote=origin --push"
echo
echo "  ${P}# 2) set the secrets on it${X}"
echo "  gh secret set CLAUDE_CODE_OAUTH_TOKEN   # from: claude setup-token"
echo "  gh secret set OPENAI_API_KEY            # Codex cross-audit (optional)"
echo "  gh secret set SDLC_BOT_TOKEN            # fine-grained PAT: Contents + PRs = write"
echo
echo "  ${P}# 3) install the loop (labels + workflows + CODEOWNERS + branch protection)${X}"
echo "  $COMPASS_ROOT/sdlc/setup.sh --all"
echo
echo "  ${P}# 4) fire the headline test — open the buggy PR, then watch the Actions tab${X}"
echo "  gh pr create --head bug/off-by-one --title 'smoke: buggy calc' --body 'agents should catch + fix this'"
echo
echo "${B}Expected:${X} sdlc-review goes ${Y}red${X} + labels ${B}agent:needs-fix${X} → sdlc-fix commits a fix on the"
echo "branch → review re-runs → ${G}agent:reviewed-clean${X}. Then try ${B}/revise${X}, ${B}/hold${X}, ${B}/approve${X} on the PR,"
echo "and label an issue ${B}agent:build${X} for zero-touch intake. Full checklist: sdlc/SMOKETEST.md"
echo
echo "${D}Cleanup when done:  gh repo delete compass-smoketest --yes ; rm -rf $DIR${X}"
