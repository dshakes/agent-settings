---
name: route
description: Detect the work type of a task or diff and dispatch the right specialist review/agent. Use when you're about to review or implement and want the correct domain reviewer (UI/design, API/devex, infra, docs, core) instead of a generic pass. The local mirror of the SDLC Classifier + domain-routed reviewers.
argument-hint: "[task description or 'review the current diff']"
allowed-tools: Read, Grep, Glob, Bash
---

# Route work to the right specialist

The cloud SDLC classifies each PR (`sdlc-classify.yml`) and runs domain-specific
reviewers. This skill does the same locally: classify, then dispatch.

## Steps
1. **Classify** the task/diff into ONE primary domain (default `core` if mixed):
   | Domain | Signals | Route to |
   |---|---|---|
   | `ui` | frontend, styling, components, UX | `code-reviewer` + a design/a11y pass |
   | `api` | public API/SDK, contracts, schemas | `code-reviewer` + contract/back-compat focus |
   | `infra` | CI, deploy, IaC, migrations | `k8s-operator` / careful review of blast radius |
   | `docs` | docs/markdown only | `docs-writer` |
   | `core` | library / business logic | `code-reviewer` (+ `security-auditor` if it touches authz/inputs) |
2. **Always** run, regardless of domain: a correctness review (`code-reviewer`) and,
   for anything touching auth/inputs/tenancy/secrets, `security-auditor`. Routing only
   *adds* a targeted pass — it never removes the safety-critical ones.
3. **Dispatch**: hand the diff to the chosen subagent(s) in a fresh context; collect and
   summarize findings grouped Blocking / Should-fix / Nit.

## Notes
- Bias to *more* review when uncertain — misclassifying down is the only costly error.
- This is advisory routing; it does not gate anything. The human still reviews and merges.
- **Model tiering** (separate from domain routing): `compass route "<task>"` picks the
  cheapest-correct model (haiku/sonnet/opus). It's **measured** — `compass route --eval`
  scores it against `scripts/route-evalset.tsv` and CI gates on an accuracy floor, so the
  heuristic can't silently regress. Add real mis-routes to the set as they surface.
