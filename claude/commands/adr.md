---
description: Draft an Architecture Decision Record for a load-bearing decision
argument-hint: "<the decision, e.g. 'use NATS instead of Kafka for the event bus'>"
allowed-tools: Read, Write, Grep, Glob, Bash(ls:*), Bash(git log:*)
---
Draft an ADR for: **$ARGUMENTS**

1. Find where ADRs live (`docs/adr/`, `docs/decisions/`, or ask if none) and read
   the two most recent to match numbering and format.
2. Write a new ADR with: **Title** (numbered) · **Status** (Proposed) · **Date**
   (today) · **Context** (the forces and constraints) · **Decision** (what we're
   doing, stated plainly) · **Consequences** (good and bad, honestly) ·
   **Alternatives considered** (and why rejected).
3. Keep it concrete and grounded in this codebase's actual constraints. Reference
   the invariants in `CLAUDE.md` it touches.

Show me the draft before writing the file if the decision is contentious.
