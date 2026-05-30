#!/usr/bin/env node
// test-listen.mjs — unit tests for the compass-listen command parser (pure `plan()`).
// No gh, no network, no daemon: imports the module (startup is guarded to main-only) and
// asserts the planned intent for each input. Runs in CI via scripts/test-cli.sh.
process.env.COMPASS_FLEET_REPO = "o/r";
process.env.COMPASS_CMD_PREFIX = "/";

const { plan, parseRepoAndNum } = await import("./compass-listen.mjs");

let pass = 0, fail = 0;
const eq = (name, got, want) => {
  const g = JSON.stringify(got), w = JSON.stringify(want);
  if (g === w) { pass++; console.log(`  ok   ${name}`); }
  else { fail++; console.log(`  FAIL ${name}\n       got  ${g}\n       want ${w}`); }
};

// non-commands and unknowns are ignored (so normal DMs aren't echoed at)
eq("plain text → ignore", plan("hello there"), { kind: "ignore" });
eq("unknown cmd → ignore", plan("/frobnicate x"), { kind: "ignore" });

// status
eq("status default repo", plan("/status"), { kind: "status", repo: "o/r" });
eq("status explicit repo", plan("/status a/b"), { kind: "status", repo: "a/b" });

// approve / hold / resume → relayed PR comment (governed downstream)
eq("approve #n", plan("/approve #42"),
  { kind: "gh", gh: ["pr", "comment", "-R", "o/r", "42", "--body", "/approve"], ok: "✅ relayed /approve to o/r#42." });
eq("hold with repo", plan("/hold #5 a/b"),
  { kind: "gh", gh: ["pr", "comment", "-R", "a/b", "5", "--body", "/hold"], ok: "✅ relayed /hold to a/b#5." });
eq("@botname stripped", plan("/resume@MyBot #9"),
  { kind: "gh", gh: ["pr", "comment", "-R", "o/r", "9", "--body", "/resume"], ok: "✅ relayed /resume to o/r#9." });
eq("approve missing number → usage", plan("/approve"),
  { kind: "reply", text: "⚠️ usage: /approve #<n> [owner/repo]" });

// build → label the issue
eq("build #n", plan("/build #7 a/b"),
  { kind: "gh", gh: ["issue", "edit", "-R", "a/b", "7", "--add-label", "agent:build"], ok: "🤖 dispatched a/b#7 to the build loop." });

// help
eq("help is a reply", plan("/help").kind, "reply");

// parseRepoAndNum picks repo + number regardless of order
eq("parse order-independent", parseRepoAndNum(["x/y", "#3"]), { repo: "x/y", num: "3" });

console.log(`\nlisten parser: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
