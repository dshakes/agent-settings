#!/usr/bin/env node
// compass-listen — turn a phone DM into a control surface for the fleet. Two transports,
// one command grammar. Pick by which env you set:
//
//   Telegram (universal, free)            — COMPASS_NOTIFY_TELEGRAM_TOKEN + _CHAT
//   iMessage/WhatsApp bridge (local HTTP) — COMPASS_NOTIFY_URL + _TOKEN (+ _TENANT)
//
// When YOU send a slash-command in your DM, it relays to GitHub and replies in-thread:
//   /status [owner/repo]            → one-line open-PR state
//   /approve #<n> [owner/repo]      → posts "/approve" on the PR — the GOVERNED sdlc-control
//   /hold #<n> [owner/repo]           workflow does the actual policy-gated action (ADR-0003)
//   /resume #<n> [owner/repo]
//   /build #<n> [owner/repo]        → labels issue #n agent:build (governed zero-touch intake)
//
// It NEVER merges or approves directly — it relays a comment/label; the existing governed
// workflows enforce every gate. Requires `gh` authenticated on this machine.
//
//   Telegram bot: message @BotFather → /newbot → token; DM the bot once, then read your chat id
//     from  https://api.telegram.org/bot<token>/getUpdates  (message.chat.id).
//   Run as a local daemon (launchd/systemd/tmux):  compass listen
//
// Other config: COMPASS_FLEET_REPO (default owner/repo), COMPASS_CMD_PREFIX (default "/").
// (Node 22 built-in fetch + WebSocket — zero npm dependencies.)

import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";

const DEFAULT_REPO = process.env.COMPASS_FLEET_REPO || "";
const PREFIX = process.env.COMPASS_CMD_PREFIX || "/";

const TG_TOKEN = process.env.COMPASS_NOTIFY_TELEGRAM_TOKEN || "";
const TG_CHAT = process.env.COMPASS_NOTIFY_TELEGRAM_CHAT || "";
const L_URLS = (process.env.COMPASS_NOTIFY_URL || "").split(/[, ]+/).filter(Boolean);
const L_TOKEN = process.env.COMPASS_NOTIFY_TOKEN || "";
const L_TENANT = process.env.COMPASS_NOTIFY_TENANT || "00000000-0000-0000-0000-000000000001";

const gh = (args) => new Promise((res) =>
  execFile("gh", args, { timeout: 30000, maxBuffer: 1 << 20 }, (e, out, err) =>
    res({ ok: !e, out: (out || "").trim(), err: (err || "").trim() })));

export function parseRepoAndNum(args) {
  let repo = DEFAULT_REPO, num = "";
  for (const a of args) {
    if (/^#?\d+$/.test(a)) num = a.replace(/^#/, "");
    else if (/^[\w.-]+\/[\w.-]+$/.test(a)) repo = a;
  }
  return { repo, num };
}

// PURE: map a DM line to an intent (no side effects, no gh, no network) — so it's unit-testable.
//   {kind:"ignore"}                          not a command / unknown → do nothing
//   {kind:"reply", text}                     a usage/help/error message
//   {kind:"status", repo}                    fetch + format open PRs for repo
//   {kind:"gh", gh:[...argv], ok}            run `gh <argv>`; reply ok on success
export function plan(text) {
  const body = String(text || "").trim();
  if (!body.startsWith(PREFIX)) return { kind: "ignore" };
  const [rawCmd, ...args] = body.slice(PREFIX.length).trim().split(/\s+/);
  const cmd = (rawCmd || "").toLowerCase().replace(/@\w+$/, ""); // strip @botname (Telegram groups)
  const { repo, num } = parseRepoAndNum(args);
  const needNum = num && repo;
  switch (cmd) {
    case "status": {
      const target = repo || DEFAULT_REPO;
      if (!target) return { kind: "reply", text: "⚠️ set COMPASS_FLEET_REPO or pass owner/repo." };
      return { kind: "status", repo: target };
    }
    case "approve": case "hold": case "resume":
      if (!needNum) return { kind: "reply", text: `⚠️ usage: ${PREFIX}${cmd} #<n> [owner/repo]` };
      return { kind: "gh", gh: ["pr", "comment", "-R", repo, num, "--body", `/${cmd}`], ok: `✅ relayed /${cmd} to ${repo}#${num}.` };
    case "build":
      if (!needNum) return { kind: "reply", text: `⚠️ usage: ${PREFIX}build #<issue> [owner/repo]` };
      return { kind: "gh", gh: ["issue", "edit", "-R", repo, num, "--add-label", "agent:build"], ok: `🤖 dispatched ${repo}#${num} to the build loop.` };
    case "help": case "":
      return { kind: "reply", text: `compass commands:\n${PREFIX}status [repo]\n${PREFIX}approve|hold|resume #n [repo]\n${PREFIX}build #issue [repo]` };
    default:
      return { kind: "ignore" }; // unknown → don't echo at normal DMs
  }
}

// Execute a plan against GitHub and respond via the transport's `reply`.
async function handle(text, reply) {
  const p = plan(text);
  if (p.kind === "ignore") return;
  if (p.kind === "reply") return reply(p.text);
  if (p.kind === "status") {
    const r = await gh(["pr", "list", "-R", p.repo, "--state", "open", "--json", "number,title,labels", "--limit", "20"]);
    if (!r.ok) return reply(`⚠️ status failed: ${r.err.slice(0, 200)}`);
    let prs = []; try { prs = JSON.parse(r.out); } catch { /* ignore */ }
    if (!prs.length) return reply(`🟢 ${p.repo}: no open PRs.`);
    const line = (pr) => {
      const L = (pr.labels || []).map((x) => x.name);
      const st = L.includes("sdlc:needs-human") ? "🟠" : L.includes("agent:needs-fix") ? "🔴" : L.includes("agent:reviewed-clean") ? "🟢" : "🔵";
      return `${st} #${pr.number} ${pr.title.slice(0, 40)}`;
    };
    return reply(`🧭 ${p.repo}\n` + prs.map(line).join("\n"));
  }
  if (p.kind === "gh") {
    const r = await gh(p.gh);
    return reply(r.ok ? p.ok : `⚠️ failed: ${r.err.slice(0, 200)}`);
  }
}

// ── Telegram transport (long-poll getUpdates) ─────────────────────────────────
async function runTelegram() {
  const api = (m) => `https://api.telegram.org/bot${TG_TOKEN}/${m}`;
  const send = (t) => fetch(api("sendMessage"), { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ chat_id: TG_CHAT, text: t }) }).catch(() => {});
  console.error(`compass listen: Telegram bot, chat ${TG_CHAT}`);
  let offset = 0;
  for (;;) {
    try {
      const r = await fetch(api(`getUpdates?timeout=30&offset=${offset}`));
      const j = await r.json();
      if (j && j.ok) for (const u of j.result) {
        offset = u.update_id + 1;
        const m = u.message || u.channel_post;
        if (!m || typeof m.text !== "string") continue;
        if (String(m.chat?.id) !== String(TG_CHAT)) continue; // only the authorized chat
        await handle(m.text, send).catch((e) => console.error("handle:", e?.message));
      }
    } catch (e) { console.error("telegram poll:", e?.message); await new Promise((r) => setTimeout(r, 3000)); }
  }
}

// ── iMessage/WhatsApp bridge transport (local HTTP + WebSocket) ───────────────
function runBridge() {
  const base = L_URLS[0].replace(/\/$/, "");
  const wsUrl = `${base.replace(/^http/, "ws")}/ws?tenantId=${encodeURIComponent(L_TENANT)}&token=${encodeURIComponent(L_TOKEN)}`;
  const send = (t) => fetch(`${base}/session/${L_TENANT}/send-self`, { method: "POST", headers: { Authorization: `Bearer ${L_TOKEN}`, "content-type": "application/json" }, body: JSON.stringify({ message: t }) }).catch(() => {});
  let backoff = 1000;
  const connect = () => {
    const ws = new WebSocket(wsUrl);
    ws.addEventListener("open", () => { backoff = 1000; console.error(`compass listen: iMessage/WhatsApp bridge ${base} (tenant ${L_TENANT})`); });
    ws.addEventListener("message", (ev) => {
      let m; try { m = JSON.parse(String(ev.data)); } catch { return; }
      if (m?.type !== "message") return;
      const d = m.data || {};
      if (d.isGroup || typeof d.text !== "string") return;
      handle(d.text, send).catch((e) => console.error("handle:", e?.message));
    });
    ws.addEventListener("close", () => { setTimeout(connect, backoff); backoff = Math.min(backoff * 2, 30000); });
    ws.addEventListener("error", () => { try { ws.close(); } catch { /* ignore */ } });
  };
  connect();
}

// Start the daemon only when run directly (so `import`-ing for tests stays side-effect-free).
const isMain = process.argv[1] && process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  if (TG_TOKEN && TG_CHAT) runTelegram();
  else if (L_URLS.length && L_TOKEN) runBridge();
  else {
    console.error("compass listen: configure a transport — Telegram (COMPASS_NOTIFY_TELEGRAM_TOKEN + _CHAT) or an iMessage/WhatsApp bridge (COMPASS_NOTIFY_URL + _TOKEN).");
    process.exit(1);
  }
}
