#!/usr/bin/env bash
# orchestrate.sh — headless, task-ordered SDLC pipeline (run from your target repo).
#
# Agents hand off IN ORDER through a shared run-dir (.sdlc/run-*) and the feature
# branch; each reads the prior agents' outputs. The PR is the human gate — this
# script never merges or deploys.
#
#   Plan → Build → Review → Audit(Codex) → Security → QA → open PR (STOP)
#
# Usage:
#   ~/compass/sdlc/orchestrate.sh "Add rate limiting to the login endpoint"
# Env:
#   SDLC_NO_PR=1     stop before opening a PR (inspect the branch yourself)
#   SDLC_YOLO=1      Builder runs --permission-mode bypassPermissions (fully unattended)
#   SDLC_BUDGET=8    total USD budget hint; per-Claude-step cap is BUDGET/4
#   SDLC_BASE=main   base branch for the PR (default: current branch)
#   SDLC_CONVERGE=1  after review, loop fix→re-review until CLEAN or SDLC_MAX_FIX_ROUNDS (default 3)
#   SDLC_SPEC=path   spec-driven: plan/build to this spec; review verifies vs its acceptance criteria
set -uo pipefail

TASK="${1:-}"; [ -n "$TASK" ] || { echo "usage: orchestrate.sh \"<task description>\""; exit 2; }
SDLC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROLES="$SDLC_DIR/roles"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "run inside the target git repo"; exit 2; }
command -v claude >/dev/null || { echo "claude CLI required"; exit 2; }

TS="$(date +%Y%m%d-%H%M%S)"
RUN=".sdlc/run-$TS"; mkdir -p "$RUN"
BASE="${SDLC_BASE:-$(git symbolic-ref --short HEAD 2>/dev/null || echo main)}"
SLUG="$(printf '%s' "$TASK" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | cut -c1-40)"
BRANCH="sdlc/${SLUG:-task}-$TS"
BUDGET="${SDLC_BUDGET:-8}"; STEP_BUDGET="$(awk "BEGIN{printf \"%.2f\", $BUDGET/4}")"
BUILD_PERM="acceptEdits"; [ "${SDLC_YOLO:-0}" = 1 ] && BUILD_PERM="bypassPermissions"

# Spec-driven (opt-in): if SDLC_SPEC points at a spec file, plan/build to it and review vs it.
SPEC_CLAUSE=""
if [ -n "${SDLC_SPEC:-}" ] && [ -f "$SDLC_SPEC" ]; then
  SPEC_CLAUSE="

This work has a SPEC at $SDLC_SPEC — read it and treat its Acceptance Criteria as the contract; respect its Non-goals."
fi

log(){ printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
note(){ printf '  %s\n' "$*"; }

# claude_step <name> <role> <model> <perm> <tools> <prompt>  -> $RUN/<name>.md
claude_step(){
  local name="$1" role="$2" model="$3" perm="$4" tools="$5" prompt="$6"
  log "$name  (claude · $model)"
  claude -p "$prompt" \
    --model "$model" \
    --append-system-prompt-file "$ROLES/$role" \
    --permission-mode "$perm" \
    --allowedTools "$tools" \
    --max-turns 25 --max-budget-usd "$STEP_BUDGET" \
    --output-format text 2>>"$RUN/orchestrate.log" | tee "$RUN/$name.md"
}

echo "compass · SDLC pipeline"
note "task:   $TASK"
note "base:   $BASE   branch: $BRANCH"
note "run:    $RUN   (budget ~\$$BUDGET, build perm: $BUILD_PERM)"
git checkout -b "$BRANCH" >/dev/null 2>&1 || { echo "could not create branch $BRANCH"; exit 2; }

# 1 · PLAN (read-only)
claude_step plan planner.md opus plan \
  "Read,Grep,Glob,Bash(git log:*),Bash(git diff:*)" \
  "Task: $TASK
Produce a concrete, minimal implementation plan for this repo. Write nothing but the plan.$SPEC_CLAUSE"

# tools the Builder may use (reused by the converge loop below)
BUILD_TOOLS="Read,Edit,Write,Grep,Glob,Bash(git add:*),Bash(git commit:*),Bash(go build:*),Bash(go test:*),Bash(go vet:*),Bash(cargo build:*),Bash(cargo test:*),Bash(npm:*),Bash(pnpm:*),Bash(npx tsc:*),Bash(pytest:*),Bash(ruff:*),Bash(make:*)"
REVIEW_TOOLS="Read,Grep,Glob,Bash(git diff:*),Bash(git log:*)"
REVIEW_PROMPT="Review the diff of branch $BRANCH against $BASE: run 'git diff $BASE...HEAD'. Report findings grouped Blocking / Should-fix / Nit. ${SDLC_SPEC:+Also read the spec at $SDLC_SPEC and verify the diff satisfies its Acceptance Criteria — treat any unmet criterion or out-of-scope change as Blocking. }End with EXACTLY one line: 'SDLC-VERDICT: BLOCKING' if there is any Blocking finding, else 'SDLC-VERDICT: CLEAN'."

# 2 · BUILD (edits + commits on the feature branch)
claude_step build builder.md sonnet "$BUILD_PERM" "$BUILD_TOOLS" \
  "Implement the plan in .sdlc/run-$TS/plan.md for this task: $TASK
Stay on branch $BRANCH. Add tests. Build/test what you touch. Commit your work. Do not push or merge.$SPEC_CLAUSE"
# safety net: capture any uncommitted work so the diff/PR is complete
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A && git commit -q -m "sdlc(builder): $TASK" && note "committed builder leftovers"
fi

# 3 · REVIEW (Claude, read-only)
claude_step review reviewer.md sonnet plan "$REVIEW_TOOLS" "$REVIEW_PROMPT"

# 3b · CONVERGE (opt-in: SDLC_CONVERGE=1) — address findings and re-review until clean or cap.
# The local mirror of the cloud loop's "review ⇄ fix until green." Humans still merge.
if [ "${SDLC_CONVERGE:-0}" = 1 ]; then
  MAXR="${SDLC_MAX_FIX_ROUNDS:-3}"; r=1
  while grep -qiE '^SDLC-VERDICT: BLOCKING' "$RUN/review.md" 2>/dev/null && [ "$r" -le "$MAXR" ]; do
    log "converge round $r/$MAXR  (fix → re-review)"
    claude_step "fix-$r" builder.md sonnet "$BUILD_PERM" "$BUILD_TOOLS" \
      "Address every Blocking and Should-fix item in .sdlc/run-$TS/review.md on branch $BRANCH for task: $TASK.
Edit the code, add/adjust tests, build/test what you touch, commit. Do not push or merge."
    if ! git diff --quiet || ! git diff --cached --quiet; then
      git add -A && git commit -q -m "sdlc(converge $r): $TASK"
    fi
    claude_step review reviewer.md sonnet plan "$REVIEW_TOOLS" "$REVIEW_PROMPT"
    r=$((r + 1))
  done
  if grep -qiE '^SDLC-VERDICT: BLOCKING' "$RUN/review.md" 2>/dev/null; then
    note "converge hit cap ($MAXR) — review still BLOCKING; a human is needed."
  else
    note "converge: review is CLEAN."
  fi
fi

# 4 · AUDIT (Codex cross-tool, read-only) — independent second opinion
log "audit  (codex · cross-tool)"
if command -v codex >/dev/null; then
  codex exec --sandbox read-only -o "$RUN/audit.md" \
    "Independently audit the changes on this branch ('git diff $BASE...HEAD') — a second
opinion to the Claude review. Flag correctness regressions, security, and missed edge
cases. Be concise; lead with anything Blocking." >>"$RUN/orchestrate.log" 2>&1 \
    && cat "$RUN/audit.md" || note "codex audit failed (see $RUN/orchestrate.log)"
else
  note "codex CLI not found — skipping cross-audit (install it for the Claude↔Codex audit)"
fi

# 5 · SECURITY (Claude, read-only)
claude_step security security.md opus plan \
  "Read,Grep,Glob,Bash(git diff:*)" \
  "Security-audit the diff of $BRANCH against $BASE ('git diff $BASE...HEAD')."

# 6 · QA (run the suite directly for a deterministic result)
log "qa  (test suite)"
{
  if [ -f Makefile ] && grep -qE '^test:' Makefile; then make test
  elif [ -f go.mod ]; then go test ./...
  elif [ -f Cargo.toml ]; then cargo test
  elif [ -f package.json ]; then npm test --silent
  elif [ -f pyproject.toml ] || [ -d tests ]; then pytest -q
  else echo "no recognized test setup — skipped"; fi
} >"$RUN/qa.log" 2>&1; QA_RC=$?
note "qa exit=$QA_RC (full log: $RUN/qa.log)"; tail -5 "$RUN/qa.log" | sed 's/^/    /'

# 7 · GATE — open a PR for human merge (never auto-merge/deploy)
log "gate  (open PR for human review)"
if [ "${SDLC_NO_PR:-0}" = 1 ]; then
  note "SDLC_NO_PR set — branch $BRANCH ready; PR not opened."
elif command -v gh >/dev/null; then
  git push -u origin "$BRANCH" >>"$RUN/orchestrate.log" 2>&1 || note "push failed (see log)"
  {
    echo "## Autonomous SDLC run — \`$TASK\`"
    echo; echo "Pipeline: Plan → Build → Review → Codex audit → Security → QA. **Human merge gate.**"
    echo; echo "### QA"; echo '```'; tail -15 "$RUN/qa.log"; echo '```'
    echo; echo "### Review (Claude)"; sed -n '1,40p' "$RUN/review.md" 2>/dev/null
    echo; echo "### Cross-audit (Codex)"; sed -n '1,40p' "$RUN/audit.md" 2>/dev/null || echo "_skipped_"
    echo; echo "### Security"; sed -n '1,40p' "$RUN/security.md" 2>/dev/null
    echo; echo "<sub>Generated by compass sdlc/orchestrate.sh · artifacts in \`$RUN\` · do not merge without human review.</sub>"
  } >"$RUN/pr-body.md"
  gh pr create --base "$BASE" --head "$BRANCH" --title "sdlc: $TASK" --body-file "$RUN/pr-body.md" \
    && note "PR opened — review and merge it yourself." || note "gh pr create failed (see log)"
else
  note "gh not found — branch $BRANCH pushed-pending; open the PR manually."
fi

log "done — artifacts in $RUN  ·  remember: humans merge & deploy, agents don't."
