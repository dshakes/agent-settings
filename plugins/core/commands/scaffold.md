---
description: Scaffold a new module/service following this repo's existing conventions
argument-hint: "<what to scaffold, e.g. 'a Go service called billing'>"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---
Scaffold: **$ARGUMENTS**

1. Find the closest existing sibling (another service/module of the same kind) and
   read its layout, build files, config wiring, tests, and observability setup.
   **Mirror it** — directory structure, naming, error handling, DI, telemetry.
2. Create the new module with the same conventions: build/manifest files, a
   minimal working entrypoint, a passing smoke test, and the wiring needed to
   build alongside the rest of the repo.
3. Build it and run its test to prove it compiles and passes. Use the
   language-appropriate engineer subagent (**go-engineer** / **rust-engineer**) for
   the implementation if it's substantial.

Report the files created and the build/test result. Don't wire it into production
config (routing, ArgoCD apps) unless I ask.
