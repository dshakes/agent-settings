#!/usr/bin/env node
// compass-listen — turn your iMessage/WhatsApp into a control surface for the fleet.
//
// Subscribes to lantern's bridge WebSocket (the bridge already broadcasts inbound DMs as
// {type:"message", data:{from,text,isGroup}} — see lantern session.ts), and when YOU send a
// slash-command in your DM, it relays it to GitHub and replies in the same thread.
//
//   /status [owner/repo]            → a one-line state of open PRs
//   /approve #<n> [owner/repo]      → posts "/approve" on the PR (the governed sdlc-control
//   /hold #<n> [owner/repo]           workflow does the actual, policy-gated action — ADR-0003)
//   /resume #<n> [owner/repo]
//   /build #<n> [owner/repo]        → labels issue #n agent:build (governed zero-touch intake)
//
// It NEVER merges or approves directly — it relays a comment/label; the existing governed
// workflows enforce the gates. Requires `gh` authenticated on this machine + a reachable bridge.
//
// Config (env):
//   COMPASS_NOTIFY_URL     bridge base URL (first entry used), e.g. http://127.0.0.1:3100
//   COMPASS_NOTIFY_TOKEN   bridge bearer token
//   COMPASS_NOTIFY_TENANT  tenant id (default the dev tenant)
//   COMPASS_FLEET_REPO     default owner/repo when a command omits one
//   COMPASS_CMD_PREFIX     command prefix (default "/")
//
// Run it as a local daemon (launchd/systemd/tmux): node scripts/compass-listen.mjs  (or: compass listen)
// NOTE: lantern's bridge may ALSO auto-reply to your DMs with its own assistant — pause the bot for
// your self-chat (lantern: /session/<tenant>/bot/pause) so commands aren't double-handled.

import { execFile } from "node:child_process";

const URLS = (process.env.COMPASS_NOTIFY_URL || process.env.LANTERN_BRIDGE_URL || "").split(/[, ]+/).filter(Boolean);
const TOKEN = process.env.COMPASS_NOTIFY_TOKEN || process.env.LANTERN_BRIDGE_TOKEN || "";
const TENANT = process.env.COMPASS_NOTIFY_TENANT || process.env.LANTERN_DEFAULT_TENANT_ID || "00000000-0000-0000-0000-000000000001";
const DEFAULT_REPO = process.env.COMPASS_FLEET_REPO || "";
const PREFIX = process.env.COMPASS_CMD_PREFIX || "/";

if (!URLS.length || !TOKEN) {
  console.error("compass listen: set COMPASS_NOTIFY_URL and COMPASS_NOTIFY_TOKEN (the lantern bridge).");
  process.exit(1);
}
const base = URLS[0].replace(/\/$/, "");
const wsUrl = `${base.replace(/^http/, "ws")}/ws?tenantId=${encodeURIComponent(TENANT)}&token=${encodeURIComponent(TOKEN)}`;

const sh = (cmd, args) => new Promise((res) =>
  execFile(cmd, args, { timeout: 30000, maxBuffer: 1 << 20 }, (e, out, err) => res({ ok: !e, out: (out || "").trim(), err: (err || "").trim() })));

async function reply(text) {
  // Reply in the same thread via the bridge self-send endpoint.
  const r = await sh("curl", ["-fsS", "-m", "15", "-X", "POST",
    `${base}/session/${TENANT}/send-self`,
    "-H", `Authorization: Bearer ${TOKEN}`, "-H", "Content-Type: application/json",
    "--data-binary", JSON.stringify({ message: text })]);
  if (!r.ok) console.error("reply failed:", r.err);
}

function parseRepoAndNum(args) {
  let repo = DEFAULT_REPO, num = "";
  for (const a of args) {
    if (/^#?\d+$/.test(a)) num = a.replace(/^#/, "");
    else if (/^[\w.-]+\/[\w.-]+$/.test(a)) repo = a;
  }
  return { repo, num };
}

async function handle(text) {
  const body = text.trim();
  if (!body.startsWith(PREFIX)) return; // not a command
  const [cmd, ...args] = body.slice(PREFIX.length).trim().split(/\s+/);
  const { repo, num } = parseRepoAndNum(args);
  const needNum = () => num && repo;

  switch ((cmd || "").toLowerCase()) {
    case "status": {
      const target = repo || DEFAULT_REPO;
      if (!target) return reply("⚠️ set COMPASS_FLEET_REPO or pass owner/repo.");
      const r = await sh("gh", ["pr", "list", "-R", target, "--state", "open", "--json", "number,title,labels", "--limit", "20"]);
      if (!r.ok) return reply(`⚠️ status failed: ${r.err.slice(0, 200)}`);
      let prs = []; try { prs = JSON.parse(r.out); } catch { /* ignore */ }
      if (!prs.length) return reply(`🟢 ${target}: no open PRs.`);
      const line = (p) => {
        const L = (p.labels || []).map((x) => x.name);
        const st = L.includes("sdlc:needs-human") ? "🟠" : L.includes("agent:needs-fix") ? "🔴" : L.includes("agent:reviewed-clean") ? "🟢" : "🔵";
        return `${st} #${p.number} ${p.title.slice(0, 40)}`;
      };
      return reply(`🧭 ${target}\n` + prs.map(line).join("\n"));
    }
    case "approve": case "hold": case "resume": {
      if (!needNum()) return reply(`⚠️ usage: ${PREFIX}${cmd} #<n> [owner/repo]`);
      // Relay as a PR comment — the governed sdlc-control workflow enforces the gate (ADR-0003).
      const r = await sh("gh", ["pr", "comment", "-R", repo, num, "--body", `/${cmd}`]);
      return reply(r.ok ? `✅ relayed /${cmd} to ${repo}#${num}.` : `⚠️ failed: ${r.err.slice(0, 200)}`);
    }
    case "build": {
      if (!needNum()) return reply(`⚠️ usage: ${PREFIX}build #<issue> [owner/repo]`);
      const r = await sh("gh", ["issue", "edit", "-R", repo, num, "--add-label", "agent:build"]);
      return reply(r.ok ? `🤖 dispatched ${repo}#${num} to the build loop.` : `⚠️ failed: ${r.err.slice(0, 200)}`);
    }
    case "help": case undefined: case "":
      return reply(`compass commands:\n${PREFIX}status [repo]\n${PREFIX}approve|hold|resume #n [repo]\n${PREFIX}build #issue [repo]`);
    default:
      return; // unknown → ignore (so normal DMs aren't echoed at)
  }
}

let backoff = 1000;
function connect() {
  const ws = new WebSocket(wsUrl);
  ws.addEventListener("open", () => { backoff = 1000; console.error(`compass listen: connected to ${base} (tenant ${TENANT})`); });
  ws.addEventListener("message", (ev) => {
    let m; try { m = JSON.parse(String(ev.data)); } catch { return; }
    if (m?.type !== "message") return;
    const d = m.data || {};
    if (d.isGroup) return;                 // DMs only
    if (typeof d.text !== "string") return;
    handle(d.text).catch((e) => console.error("handle error:", e?.message));
  });
  ws.addEventListener("close", () => { setTimeout(connect, backoff); backoff = Math.min(backoff * 2, 30000); });
  ws.addEventListener("error", () => { try { ws.close(); } catch { /* ignore */ } });
}
connect();
