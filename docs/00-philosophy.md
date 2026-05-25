# Philosophy

The operating beliefs behind every choice in this repo. If a future change
contradicts one of these, change the belief on purpose — don't drift.

### 1. Configuration is the moat, not the model
Everyone has the same models. The leverage is in what the agent knows by default,
what it's allowed to do, what it does without being asked, and which model does
which job. That's all configuration — so we version it, review it, and share it.

### 2. Grounded over impressive
No fabricated "this is what famous-person-X uses." Every feature here maps to a
documented Claude Code / Codex capability. Configs describe what *is*, verified,
not what would sound good. Aspirational config is worse than none — it teaches the
agent to lie.

### 3. Short, true context beats long context
The global `CLAUDE.md` is deliberately small. Every line in a memory file competes
for attention with the actual task. We cut rules that aren't earning their place.

### 4. Guardrails, not handcuffs
Hooks block the handful of actions that are catastrophic and almost never intended
(secret writes, `rm -rf /`, force-push to main). Everything else flows to normal
permission rules. The goal is to make the right thing easy and the irreversible
thing hard — not to nag.

### 5. Spend the expensive model only where it pays
Mechanical and parallel work goes to cheap models via subagents; deep reasoning
stays on Opus. Most of a task's tokens are mechanical. Routing them correctly is
the single biggest cost lever, and it usually makes things *faster* too.

### 6. Verify, then claim
A change isn't done until it's been exercised. The whole toolchain — test-runner
subagent, format-on-edit, `/ship` — exists so "it works" means "I ran it," not "it
looks right."

### 7. The human owns the irreversible
Push, merge, deploy, publish, delete shared state: the agent prepares, the human
commits. Approval is per-action and per-context; it never carries over silently.

### 8. Built to be cloned
This is a template for a team and for strangers. Universal principles live at the
top; stack-specific defaults are clearly marked and deletable. One source of truth
(`CLAUDE.md` ≙ `AGENTS.md`) so Claude and Codex behave the same.
