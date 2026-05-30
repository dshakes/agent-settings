#!/usr/bin/env bash
# compass-notify.sh — push a message to your phone. Channel-agnostic: it sends to EVERY
# backend you've configured via env, and is a graceful no-op if you've configured none.
# So compass's mobile layer never hard-depends on any one service.
#
#   compass notify "🔍 PR #234 green, tests added. Reply approve / hold"
#   echo "multi-line body" | compass notify
#   compass notify --dry-run "test"      # print what it would send, send nothing
#
# Backends (set whichever you use — any combination):
#   COMPASS_NOTIFY_SLACK        Slack incoming-webhook URL            → {"text": msg}
#   COMPASS_NOTIFY_DISCORD      Discord webhook URL                   → {"content": msg}
#   COMPASS_NOTIFY_TELEGRAM_TOKEN + COMPASS_NOTIFY_TELEGRAM_CHAT      → Telegram sendMessage (free, two-way)
#   COMPASS_NOTIFY_NTFY         an ntfy.sh topic URL                  → plain-text body
#   COMPASS_NOTIFY_WEBHOOK      any URL                               → {"text": msg, "content": msg, "message": msg}
#   COMPASS_NOTIFY_URL+_TOKEN   lantern bridge (iMessage/WhatsApp)    → /session/<tenant>/send-self  (optional, premium)
#                               (+ COMPASS_NOTIFY_TENANT)
#
# No backend configured → no-op (exit 0). For most open-source users, Slack/Discord/Telegram is the
# 2-minute path; GitHub Mobile already covers approve/merge/trigger natively (see docs/14-fleet.md).
set -uo pipefail

DRY=0; REQUIRE=0; MSG=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --require) REQUIRE=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) MSG="${MSG:+$MSG }$a" ;;
  esac
done
[ -z "$MSG" ] && [ ! -t 0 ] && MSG="$(cat)"
[ -n "$MSG" ] || { echo "compass notify: empty message" >&2; exit 2; }

# JSON-string-encode (jq → python3 → minimal).
jstr() {
  if command -v jq >/dev/null 2>&1; then printf '%s' "$1" | jq -Rs .
  elif command -v python3 >/dev/null 2>&1; then printf '%s' "$1" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))'
  else local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; printf '"%s"' "$s"; fi
}
M="$(jstr "$MSG")"

sent=0 configured=0 rc=0
post() {  # post <label> <url> <content-type> <body>
  configured=1
  if [ "$DRY" = 1 ]; then printf '→ %s: POST %s\n  %s\n' "$1" "$2" "$4"; sent=1; return; fi
  command -v curl >/dev/null 2>&1 || { echo "compass notify: curl not found" >&2; rc=1; return; }
  if curl -fsS -m 15 -X POST "$2" -H "Content-Type: $3" --data-binary "$4" >/dev/null 2>&1; then
    echo "compass notify: sent via $1" >&2; sent=1
  else echo "compass notify: send failed ($1)" >&2; rc=1; fi
}

[ -n "${COMPASS_NOTIFY_SLACK:-}" ]   && post slack   "$COMPASS_NOTIFY_SLACK"   "application/json" "{\"text\":$M}"
[ -n "${COMPASS_NOTIFY_DISCORD:-}" ] && post discord "$COMPASS_NOTIFY_DISCORD" "application/json" "{\"content\":$M}"
[ -n "${COMPASS_NOTIFY_WEBHOOK:-}" ] && post webhook "$COMPASS_NOTIFY_WEBHOOK" "application/json" "{\"text\":$M,\"content\":$M,\"message\":$M}"
[ -n "${COMPASS_NOTIFY_NTFY:-}" ]    && post ntfy    "$COMPASS_NOTIFY_NTFY"    "text/plain" "$MSG"
if [ -n "${COMPASS_NOTIFY_TELEGRAM_TOKEN:-}" ] && [ -n "${COMPASS_NOTIFY_TELEGRAM_CHAT:-}" ]; then
  post telegram "https://api.telegram.org/bot${COMPASS_NOTIFY_TELEGRAM_TOKEN}/sendMessage" "application/json" "{\"chat_id\":\"${COMPASS_NOTIFY_TELEGRAM_CHAT}\",\"text\":$M}"
fi
# lantern bridge (iMessage/WhatsApp) — optional, premium. One or more comma/space-separated base URLs.
LURLS="${COMPASS_NOTIFY_URL:-${LANTERN_BRIDGE_URL:-}}"; LTOK="${COMPASS_NOTIFY_TOKEN:-${LANTERN_BRIDGE_TOKEN:-}}"
LTEN="${COMPASS_NOTIFY_TENANT:-${LANTERN_DEFAULT_TENANT_ID:-00000000-0000-0000-0000-000000000001}}"
if [ -n "$LURLS" ] && [ -n "$LTOK" ]; then
  for base in ${LURLS//,/ }; do
    base="${base%/}"; configured=1
    if [ "$DRY" = 1 ]; then printf '→ lantern: POST %s\n  {"message":%s}\n' "$base/session/$LTEN/send-self" "$M"; sent=1; continue; fi
    if curl -fsS -m 15 -X POST "$base/session/$LTEN/send-self" -H "Authorization: Bearer $LTOK" -H "Content-Type: application/json" --data-binary "{\"message\":$M}" >/dev/null 2>&1; then
      echo "compass notify: sent via lantern ($base)" >&2; sent=1
    else echo "compass notify: send failed (lantern $base)" >&2; rc=1; fi
  done
fi

if [ "$configured" = 0 ]; then
  [ "$REQUIRE" = 1 ] && { echo "compass notify: no backend configured (set COMPASS_NOTIFY_SLACK/_DISCORD/_TELEGRAM_*/_WEBHOOK/_NTFY or the lantern bridge)" >&2; exit 1; }
  echo "compass notify: no backend configured — skipping (see compass notify --help)" >&2; exit 0
fi
exit "$rc"
