---
description: Re-plan the current task to minimize model cost without losing quality
argument-hint: "[optional: the task to optimize]"
---
Look at what we're about to do${ARGUMENTS:+: $ARGUMENTS} and propose the
cheapest *correct* execution plan.

- Which parts are mechanical or parallel and should go to **Haiku** subagents
  (test runs, formatting, log triage, broad code searches, repetitive edits)?
- Which parts are standard coding/refactoring that fit a **Sonnet** subagent?
- Which parts genuinely need **Opus**-level reasoning in the driver (architecture,
  security, subtle debugging)?
- Where am I about to re-read files or re-run searches I could delegate once and
  keep only the conclusion?

Give me the delegation plan as a short table (task → model/subagent → why), then
proceed with it once I'm happy.
