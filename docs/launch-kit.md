# Launch kit (internal) — submit & announce compass

Everything needed to list compass on **awesome-claude-code** and announce it. Prepared
ahead of time; **you** do the submitting/posting as a human (see why below).

> **Eligibility gate:** awesome-claude-code requires *"over one week since the first public
> commit."* compass's first commit was **2026-05-25** → **submit on or after 2026-06-02.**
> A calendar reminder was created for that date.

---

## 1. List on awesome-claude-code

**Their rules (do NOT break — they ban for it):** submissions are **Web-UI issue-form only**.
**Do not open a PR. Do not use the `gh` CLI. Must be submitted by a human.** (So there is no
"raise a PR" here — the one-click action is the pre-filled issue form; the maintainer's bot
turns an approved issue into the PR automatically.)

### ✅ One-click action (open on/after 2026-06-02)
Opens the issue form with the dropdowns + short fields pre-filled:

```
https://github.com/hesreallyhim/awesome-claude-code/issues/new?template=recommend-resource.yml&title=%5BResource%5D+compass+%E2%80%94+config+manager+for+Claude+Code+%2B+Codex&display_name=compass&category=Tooling&subcategory=Tooling%3A+Config+Managers&primary_link=https%3A%2F%2Fgithub.com%2Fdshakes%2Fcompass&author_name=Shekhar+Mudarapu&author_link=https%3A%2F%2Fgithub.com%2Fdshakes&license=MIT
```

If any field didn't pre-fill, set it manually (verbatim — these match their dropdowns exactly):

| Field | Value |
|---|---|
| Display Name | `compass` |
| Category | `Tooling` |
| Sub-Category | `Tooling: Config Managers` |
| Primary Link | `https://github.com/dshakes/compass` |
| Author Name | `Shekhar Mudarapu` |
| Author Link | `https://github.com/dshakes` |
| License | `MIT` |

### Paste into "Description"
> compass is a **config manager** for Claude Code + Codex: one source of truth, symlinked into `~/.claude` and `~/.codex`, that makes both tools behave consistently in every repo. It ships a lean operating manual (`CLAUDE.md` ≙ `AGENTS.md` via symlink — one source for both tools), guardrail + auto-format hooks, cost-tiered specialist subagents, workflow commands, and an optional **human-gated autonomous PR loop** (label an issue *or* open a PR → review → security → tests → Codex cross-audit → **auto-fixes its own Blocking findings** → re-review → you merge), steerable mid-flight from a PR comment (`/revise`, `/hold`, `/approve`). The loop is **validated end-to-end on a live repo**.
>
> It's **modular** — the manual + guardrails are the core; everything else is opt-in. A small `compass` CLI adds local tooling: `compass onboard` gets you productive in a new repo in minutes, and `compass impact` shows what it actually saved you (footguns blocked, files auto-formatted, `$` saved by cheap-model tiering). Two more optional notes: the `AGENTS.md` standard means the same manual also feeds Cursor/Windsurf/Copilot (and Gemini CLI via `--gemini`), and the Codex cheap tier can run on a local model or a cost router. Use as little or as much as you want.
>
> **Install:** `git clone https://github.com/dshakes/compass ~/compass && cd ~/compass && make install && make doctor`. **Uninstall:** `make uninstall` (removes only what it created). Zero-setup alternative inside Claude Code: `/plugin marketplace add dshakes/compass` then `/plugin install core@compass`.
>
> **Disclosures (per CONTRIBUTING):** Modifies shared files — symlinks config into `~/.claude`, `~/.codex`, and (with `--gemini`) `~/.gemini` (idempotent, backed up, all reversible via `make uninstall`). Network beyond Anthropic only via opt-in tools: context7 + fetch MCP (auto-registered, secret-free), the opt-in cloud SDLC agents (GitHub API, OpenAI for the Codex audit), optional Playwright/Postgres MCP, and an optional Codex cost router (OpenRouter) — none enabled silently (see SECURITY.md egress table). **No telemetry. No `--dangerously-skip-permissions` anywhere.** Hooks run documented shell scripts on tool/session events (guardrails + formatting) and never fail a session. MIT.

### Paste into "Validate Claims" / "Specific Task" / "Specific Prompt"
> After `make install`, ask Claude to run `rm -rf $HOME` → it is **blocked** before executing, while `rm -rf ./build` is allowed. The autonomous loop is proven, not aspirational: on a live private repo, a buggy PR went review-**Blocking** → the Builder auto-fixed it on the branch → re-review **green** (human merge gate held); a `agent:build`-labeled issue had an agent write the change and open a PR; and a `/revise` comment steered the loop to add a requested test. Repeatable via `sdlc/SMOKETEST.md` + `scripts/smoketest-scaffold.sh`.

### See it in action (the maintainer explicitly rewards "show me before I run it")
- Renders on GitHub straight from the repo: the **animated explainer**, the **self-fixing loop diagram** (`assets/sdlc-loop.svg`), a ~25s **terminal demo** (`demo/preview.gif`), and **`assets/loop.gif` — the loop on the *real* PR #4** (Reviewer flags `Sub` Blocking → Builder pushes fix `737d589` → re-review green → you merge). Real data; regenerate with `vhs demo/loop.tape`.
- **Optional upgrade — a GitHub-UI screencast (§4):** a ~20s capture of the same loop in the PR's Checks tab. Purely nice-to-have now that `loop.gif` already shows the real run.

### Paste into "Additional Comments"
> **Unique within "Tooling: Config Managers"** — I checked the 3 current entries: **agnix** *lints* config files, **claude-rules-doctor** finds *dead* `.claude/rules/`, **ClaudeCTX** *switches* between configs. None is what compass is: an *opinionated, single-source* config for **Claude Code + Codex** (`AGENTS.md` ≙ `CLAUDE.md`, one source) that also runs an optional **governed, closed autonomous PR loop** — Claude reviews · **Codex cross-audits** · it **auto-fixes its own Blocking findings** with spec/intent verification · re-reviews until green; a labeled issue can become a PR, it's steerable mid-flight (`/revise`), and it reports its own impact (`compass impact`). Humans always merge (branch protection, not trust). (vs the broader entries: SuperClaude / Everything Claude Code are single-tool pattern frameworks; Auto-Claude / The Agentic Startup are standalone orchestrators, not a config; claude-code-tools does Claude↔Codex *handoff*, not a shared config + loop.)
> **Focused, not a marketplace:** the core is just the operating manual + guardrail hooks — one `make install` and it works immediately; *everything else* (the loop, the CLI, cross-tool, local models) is opt-in and off until you switch it on.
> **Security (your #1 concern):** no telemetry; **no `--dangerously-skip-permissions`** anywhere; **no auto-update** — you run `git pull` (no `npx @latest`); a network-egress table is in `SECURITY.md`; `install.sh` and the hooks are short and fully commented for review.
> Alpha. The loop is validated **live end-to-end** on a real repo (review-Blocking → auto-fix → green; `agent:build` issue → agent PR; `/revise` steered in a test). CI self-validates the config (actionlint/shellcheck/unit tests). Ran your `evaluate-repository.md` rubric ahead of time.

### The required checklist (tick all — they're true)
- [x] Not already submitted · [x] **over one week since first commit** (true on/after Jun 2) · [x] links work · [x] no other open issues in their repo · [x] human

**Approval odds (honest, after scanning their live repo May 2026): ~75–85%.** In favor: the *Config Managers* subcategory has only 3 entries (a linter, a dead-rule detector, a config-switcher) and compass is genuinely distinct; security posture is strong (their stated #1 filter — egress table, no telemetry, no dangerous flags, commented scripts); clear install/uninstall, demos, and a *live-validated* loop give evidence; precedent shows broad configs (SuperClaude, claude-code-tools) get listed; format is airtight (human issue-form, 1-week age gate met Jun 2). The one real swing factor: CONTRIBUTING explicitly *"values focused resources… select a small subset"* and is wary of **bloat / complex systems with long onboarding** — compass is comprehensive. Mitigation is baked into the Description/Comments: lead with the single differentiator and "the core is tiny, everything else opt-in." The decision is the maintainer's subjective focused-vs-bloat call.

### Uniqueness check (done — compass is NOT a category-of-one, but it is differentiated)
The list already has similar resources; the maintainer requires uniqueness, so lead with the real differentiator, not breadth.

**Same subcategory — Tooling: Config Managers (the 3 current entries; this is the comparison the maintainer checks):**

| Existing entry | What it is | How compass differs |
|---|---|---|
| **agnix** | a *linter/validator* for Claude config files (CLAUDE.md/AGENTS.md/SKILL.md/hooks/MCP) | compass *is* the config (a single source), not a linter for one |
| **claude-rules-doctor** | CLI that finds *dead* `.claude/rules/` (globs that match nothing) | compass ships + governs the rules cross-tool; not a dead-file detector |
| **ClaudeCTX** | *switches* your entire Claude config with one command | compass is one opinionated source + a governed loop, not a profile-switcher |

**Broader-config entries (other subcategories), for context:**

| Existing entry | What it is | Overlap | How compass differs |
|---|---|---|---|
| **SuperClaude** (General) | config framework: commands, personas, methodologies | "config framework w/ commands" | no cross-tool single source, no autonomous PR loop, no cross-model audit, no governance/ADRs |
| **Everything Claude Code** (General) | broad grab-bag of exemplary patterns | breadth | compass is *integrated + opinionated + installable* with a governed loop, not a pattern store |
| **Claude Codex Settings** (General) | cross-tool integration plugins, "not overly-opinionated" | Claude+Codex | compass is *opinionated senior-engineer defaults* + the loop, not integration plugins |
| **claude-code-tools** (General) | session continuity + Claude↔Codex handoff + safety hooks | cross-agent + hooks | compass shares one *config* across tools + a review/fix loop, not handoff/continuity |
| **Auto-Claude / The Agentic Startup** (Orchestrators) | autonomous multi-agent SDLC frameworks | "autonomous SDLC" | those are standalone orchestrators; compass is a *config* whose loop is one optional, human-gated layer with a Codex cross-audit |

**The non-arbitrary unique intersection:** an *opinionated, single-source config for both Claude Code and Codex* **+** a *governed, closed PR loop with a cross-model (Claude+Codex) second opinion, spec/intent verification, and a hard human merge gate.* No listed resource combines those. We submit under **Tooling: Config Managers** (only 3 entries — a linter, a rules-checker, a config-switcher — none opinionated configs), which is both accurate and keeps us out of the crowded "General" config-framework bucket where SuperClaude lives.

**Honest risk:** a selective curator could still see "another config framework." Mitigation is baked into the Description/Comments above — lead with the cross-tool + cross-model-loop angle, never with "comprehensive."

---

## 2. Launch post (short — X / LinkedIn / Discord)
> 🧭 **compass** — one config that makes **Claude Code, Codex *and* Gemini** behave like your best engineer in every repo. Guardrail hooks, cost-tiered subagents, a `compass` CLI that shows what it saved you, and a **human-gated autonomous PR loop**: label an issue *or* open a PR → it reviews, security-checks, tests, cross-audits with Codex, and **auto-fixes its own findings** (steer it with `/revise`) → you merge. No magic, no `curl\|sh`; every piece is a documented feature you can read. MIT, alpha. → github.com/dshakes/compass

---

## 3. Credibility pitches for public portals (post as a human, from your accounts)

> **Why you, not me:** I have no auth to these platforms, and — more importantly —
> automated/self-promo posting is exactly what these communities flag as spam (it would *hurt*
> credibility, the opposite of the goal). These are ready to post; engage genuinely and stay to
> answer comments (that's what earns trust). Check each community's self-promo rules first.

### Show HN
**Title:** `Show HN: Compass – one config so Claude Code, Codex, and Gemini act like your best engineer`
**Body:**
> I kept rebuilding the same Claude Code / Codex / Gemini setup in every repo, so I shipped it once. Compass is a config manager: it symlinks one source into ~/.claude and ~/.codex (and ~/.gemini) so the tools share a lean operating manual (AGENTS.md is a symlink to CLAUDE.md), guardrail hooks (blocks rm -rf /, secret writes, force-push to main; auto-formats edits), cost-tiered subagents (cheap models for grunt work, Opus for hard calls), and an optional, human-gated autonomous PR loop: label an issue or open a PR and it reviews, security-checks, tests, cross-audits with Codex, then auto-fixes its own Blocking findings and re-reviews until green — steerable mid-flight with /revise, and you still click merge.
> There's also a compass CLI that onboards you into a new repo and shows what it saved you (footguns blocked, $ saved). It's deliberately "no magic": every piece is a documented feature, no curl|sh, MIT, and CI validates its own config (the loop is validated live end-to-end). Alpha — I'd love feedback, especially on the loop's guardrails. Repo: https://github.com/dshakes/compass

### r/ClaudeAI (or r/ChatGPTCoding)
**Title:** `I open-sourced my Claude Code + Codex config — guardrails, cost-tiering, and an autonomous PR loop (MIT)`
**Body:** (same gist as Show HN, a touch more casual) — lead with the problem (rebuilding config per repo), the 3–4 concrete things you get, the honesty angle (read every file, no curl|sh), MIT + alpha, ask for feedback. Include the hero image.

### X / Twitter (thread)
1. I shipped **compass** 🧭 — one config that makes **Claude Code, Codex, and Gemini** behave like a senior engineer in every repo. MIT, open source. 🧵
2. It's a config manager: one source → ~/.claude + ~/.codex. Lean operating manual, guardrail hooks (blocks rm -rf /, secret writes, force-push to main), auto-format on edit.
3. Cost-tiered: grunt work → Haiku/Sonnet, Opus for the hard calls, live $ in the status line.
4. The fun part — a human-gated autonomous PR loop: **label an issue or open a PR** → review → security → tests → **Codex cross-audit** → **auto-fix its own findings** → re-review until green. Steer it mid-flight with `/revise`. You keep the merge.
5. And it proves it: `compass impact` shows footguns blocked + `$` saved. No magic, no curl|sh — every piece is a documented feature you can read. Alpha; feedback welcome 👉 github.com/dshakes/compass

### dev.to / blog (optional, highest-credibility)
A 600–900 word post: *"One config for Claude Code and Codex — and an autonomous PR loop that fixes its own review findings."* Outline: the per-repo-config problem → what compass ships → the closed loop (with the spec-driven story from SMOKETEST as the hook) → the honesty/security stance → install + uninstall. Link from the README once published.

---

## 4. Record the autonomous loop (the hero asset)

The most impressive, authentic visual is the **real loop on a PR** — review flags a Blocking
issue, the Builder pushes a fix, checks go green. You capture it (I can't screen-record); I've
made it turnkey.

### Step 1 — stage a clean BLOCKING → fix → green PR (one paste)
Run right before recording, on the smoke-test repo (workflows + `SDLC_BOT_TOKEN` already set):
```bash
cd ~/workspace/compass-sdlc-smoketest && git checkout -q main && git pull -q
git checkout -q -b demo/loop-$(date +%s)
mkdir -p specs
cat > specs/divide.md <<'EOF'
# Spec: Divide
## Acceptance criteria
1. Divide(10,2) == 5
2. Returns 0 when the divisor is 0 (no panic)
3. A table-driven test TestDivide covers both
EOF
printf 'package smoketest\n\n// Divide returns a / b.\nfunc Divide(a, b int) int { return a / b }\n' > divide.go
git add -A && git commit -q -m "feat: add Divide (per specs/divide.md)"
git push -q -u origin HEAD
gh pr create --fill --body "Implements specs/divide.md. Spec: specs/divide.md"
```
The code is "fine" but violates the spec (no zero-guard, no test) → the reviewer flags it
**Blocking**, the Builder fixes it on the branch, re-review goes **green**.

### Step 2 — record
- Open the PR; show the **Checks** + the conversation/commits. Start a screen recording
  (macOS ⌘⇧5, or Kap/CleanShot for direct GIF).
- The loop takes a few minutes, so **record the three beats and speed up later**:
  1. checks running → `review` **red** + `agent:needs-fix`
  2. the **Builder's fix commit** lands on the branch
  3. re-review → **green ✓** (mergeable, pending your approval)

### Step 3 — convert + hand back
```bash
ffmpeg -i loop.mov -vf "setpts=0.2*PTS,fps=12,scale=1000:-1:flags=lanczos" -loop 0 assets/loop.gif
```
(`setpts=0.2*PTS` = 5× speed → ~20–30s.) Then drop `assets/loop.gif` in the repo and ping me —
I'll wire it under the hero. *(MP4 alternative: upload to a GitHub Release/Issue; GitHub renders
uploaded `.mp4` as a player — paste that URL instead.)*

> Until it exists, the hero is the animated `assets/explainer.svg` (YC-style, minimal-text) +
> the terminal demo. The recording becomes the centerpiece once captured.

---

*Generated as a launch checklist. Update the eligibility date if the first-commit date changes.*
