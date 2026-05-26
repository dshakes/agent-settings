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
> compass is a **config manager** for Claude Code + Codex: one source of truth, symlinked into `~/.claude` and `~/.codex`, that makes both tools behave consistently in every repo. It ships a lean operating manual (`CLAUDE.md` ≙ `AGENTS.md` via symlink — one source for both tools), guardrail + auto-format hooks, cost-tiered specialist subagents, workflow commands, and an optional **human-gated autonomous PR loop** (review → security → tests → Codex cross-audit → auto-fix → you merge).
>
> **Install:** `git clone https://github.com/dshakes/compass ~/compass && cd ~/compass && make install && make doctor`. **Uninstall:** `make uninstall` (removes only what it created). Zero-setup alternative inside Claude Code: `/plugin marketplace add dshakes/compass` then `/plugin install core@compass`.
>
> **Disclosures (per CONTRIBUTING):** Modifies shared files — symlinks config into `~/.claude` and `~/.codex` (idempotent, backed up, reversible). Network beyond Anthropic only via opt-in tools: context7 + fetch MCP (auto-registered, secret-free) and the opt-in cloud SDLC agents (GitHub API, OpenAI for the Codex audit), plus optional Playwright/Postgres MCP — none enabled silently (see SECURITY.md egress table). **No telemetry. No `--dangerously-skip-permissions` anywhere.** Hooks run documented shell scripts on tool/session events (guardrails + formatting) and never fail a session. MIT.

### Paste into "Validate Claims" / "Specific Task" / "Specific Prompt"
> After `make install`, ask Claude to run `rm -rf $HOME` → it is **blocked** before executing, while `rm -rf ./build` is allowed. For the autonomous loop, follow `sdlc/SMOKETEST.md` on a private repo: open a PR whose code is correct but omits a test its spec requires — the spec-aware reviewer flags it **Blocking** and the Builder auto-adds the test and re-reviews to green (a real, documented run).

### Paste into "Additional Comments"
> Distinctive Claude-Code angle: one source for **both** Claude Code and Codex, plus a closed autonomous PR loop with a **cross-model (Claude + Codex) second opinion** and **spec/intent verification** — humans always own merge/deploy. Alpha; security posture in README + SECURITY.md + ADRs; CI self-validates the config (actionlint/shellcheck/unit tests). Ran your `evaluate-repository.md` rubric ahead of time.

### The required checklist (tick all — they're true)
- [x] Not already submitted · [x] **over one week since first commit** (true on/after Jun 2) · [x] links work · [x] no other open issues in their repo · [x] human

**Approval odds:** their own rubric scored compass 9/10 on security/transparency/quality; the only risk was *scope*, which the **"config manager"** framing above directly addresses. Format is airtight; approval is the maintainer's call.

---

## 2. Launch post (short — X / LinkedIn / Discord)
> 🧭 **compass** — one config that makes **Claude Code *and* Codex** behave like your best engineer in every repo. Operating manual, guardrail hooks, cost-tiered subagents, and an **autonomous PR loop** that reviews, security-checks, tests, cross-audits with Codex, and **auto-fixes its own findings** — you keep the merge. No magic, no `curl\|sh`; every piece is a documented feature you can read. MIT, alpha. → github.com/dshakes/compass

---

## 3. Credibility pitches for public portals (post as a human, from your accounts)

> **Why you, not me:** I have no auth to these platforms, and — more importantly —
> automated/self-promo posting is exactly what these communities flag as spam (it would *hurt*
> credibility, the opposite of the goal). These are ready to post; engage genuinely and stay to
> answer comments (that's what earns trust). Check each community's self-promo rules first.

### Show HN
**Title:** `Show HN: Compass – one config so Claude Code and Codex act like your best engineer`
**Body:**
> I kept rebuilding the same Claude Code / Codex setup in every repo, so I shipped it once. Compass is a config manager: it symlinks one source into ~/.claude and ~/.codex so both tools share a lean operating manual (AGENTS.md is a symlink to CLAUDE.md), guardrail hooks (blocks rm -rf /, secret writes, force-push to main; auto-formats edits), cost-tiered subagents (cheap models for grunt work, Opus for hard calls), and an optional, human-gated autonomous PR loop: open a PR and it reviews, security-checks, tests, cross-audits with Codex, then auto-fixes its own Blocking findings and re-reviews until green — you still click merge.
> It's deliberately "no magic": every piece is a documented Claude Code / Codex feature, no curl|sh, MIT, and the CI validates its own config. It's alpha and I'd love feedback, especially on the autonomous loop's guardrails. Repo: https://github.com/dshakes/compass

### r/ClaudeAI (or r/ChatGPTCoding)
**Title:** `I open-sourced my Claude Code + Codex config — guardrails, cost-tiering, and an autonomous PR loop (MIT)`
**Body:** (same gist as Show HN, a touch more casual) — lead with the problem (rebuilding config per repo), the 3–4 concrete things you get, the honesty angle (read every file, no curl|sh), MIT + alpha, ask for feedback. Include the hero image.

### X / Twitter (thread)
1. I shipped **compass** 🧭 — one config that makes **Claude Code *and* Codex** behave like a senior engineer in every repo. MIT, open source. 🧵
2. It's a config manager: one source → ~/.claude + ~/.codex. Lean operating manual, guardrail hooks (blocks rm -rf /, secret writes, force-push to main), auto-format on edit.
3. Cost-tiered: grunt work → Haiku/Sonnet, Opus for the hard calls, live $ in the status line.
4. The fun part — an autonomous PR loop: review → security → tests → **Codex cross-audit** → **auto-fix its own findings** → re-review until green. You keep the merge.
5. No magic, no curl|sh — every piece is a documented feature you can read. Alpha; feedback welcome 👉 github.com/dshakes/compass

### dev.to / blog (optional, highest-credibility)
A 600–900 word post: *"One config for Claude Code and Codex — and an autonomous PR loop that fixes its own review findings."* Outline: the per-repo-config problem → what compass ships → the closed loop (with the spec-driven story from SMOKETEST as the hook) → the honesty/security stance → install + uninstall. Link from the README once published.

---

*Generated as a launch checklist. Update the eligibility date if the first-commit date changes.*
