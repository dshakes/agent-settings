---
description: Test-driven change — write the failing test first, then implement
argument-hint: "<what to build/fix>"
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Task
---
Implement the following using strict TDD: **$ARGUMENTS**

1. **Red** — Write the smallest test that captures the desired behavior and *fails*
   for the right reason. Run it; show me the failure. Do not write implementation
   yet.
2. **Green** — Write the minimum code to make that test pass. Run it; show it pass.
3. **Refactor** — Clean up while keeping the test green. Re-run.
4. Repeat for each behavior/edge case until the requirement is fully covered.

Match the repo's existing test framework and style. Cover error paths, not just
the happy path. Use the **test-runner** subagent to execute suites so we stay cheap.
Report the final test list and results.
