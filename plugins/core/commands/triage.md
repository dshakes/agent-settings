---
description: Triage a failing test, panic, CI failure, or error log
argument-hint: "[paste error / test name / log path]"
allowed-tools: Read, Grep, Glob, Bash, Task
---
Triage this failure: $ARGUMENTS

1. Reproduce it locally if possible (run the named test / command). Capture the
   exact error and stack.
2. Delegate the root-cause hunt to the **debugger** subagent.
3. Come back with: **what's actually broken** (root cause, not symptom), the
   `file:line`, the **smallest fix**, and how to verify it.

Don't apply the fix yet — show it to me first unless it's a one-line obvious
correction.
