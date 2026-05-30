#!/usr/bin/env bash
# compass-notify.sh — push a message to your phone via lantern's iMessage/WhatsApp bridge.
#
# This is compass's mobile surface: agents (the mission-control digest, a "needs you" alert)
# call this to DM you. It POSTs to lantern's bridge self-send endpoint, which the bridge
# delivers to your own iMessage/WhatsApp thread.
#
#   compass notify "🔍 PR #234 green, tests added (cov 84%). Reply approve / hold"
#   echo "multi-line body" | compass notify           # body from stdin
#   compass notify --dry-run "test"                    # print the request, send nothing
#
# Config (env — set these where the agent runs; nothing is baked in):
#   COMPASS_NOTIFY_URL    one or more lantern bridge base URLs, space/comma-separated.
#                         e.g. "http://127.0.0.1:3100" (WhatsApp) or ":3200" (iMessage).
#                         Falls back to LANTERN_BRIDGE_URL.
#   COMPASS_NOTIFY_TOKEN  bridge bearer token. Falls back to LANTERN_BRIDGE_TOKEN.
#   COMPASS_NOTIFY_TENANT tenant id. Falls back to LANTERN_DEFAULT_TENANT_ID, then the dev default.
#
# UNCONFIGURED → graceful no-op (exit 0): a digest must never fail just because the phone
# bridge isn't wired up. Use `--require` to make a missing config an error instead.
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
# Body from stdin if no message arg and stdin is not a tty.
if [ -z "$MSG" ] && [ ! -t 0 ]; then MSG="$(cat)"; fi
[ -n "$MSG" ] || { echo "compass notify: empty message" >&2; exit 2; }

URLS="${COMPASS_NOTIFY_URL:-${LANTERN_BRIDGE_URL:-}}"
TOKEN="${COMPASS_NOTIFY_TOKEN:-${LANTERN_BRIDGE_TOKEN:-}}"
TENANT="${COMPASS_NOTIFY_TENANT:-${LANTERN_DEFAULT_TENANT_ID:-00000000-0000-0000-0000-000000000001}}"

if [ -z "$URLS" ] || [ -z "$TOKEN" ]; then
  if [ "$REQUIRE" = 1 ]; then
    echo "compass notify: COMPASS_NOTIFY_URL and COMPASS_NOTIFY_TOKEN are required" >&2; exit 1
  fi
  echo "compass notify: bridge not configured (set COMPASS_NOTIFY_URL/_TOKEN) — skipping" >&2
  exit 0
fi

# JSON-encode the message safely (jq → python3 → minimal escaping).
json_payload() {
  if command -v jq >/dev/null 2>&1; then jq -nc --arg m "$1" '{message:$m}'
  elif command -v python3 >/dev/null 2>&1; then printf '%s' "$1" | python3 -c 'import sys,json;print(json.dumps({"message":sys.stdin.read()}))'
  else local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; printf '{"message":"%s"}' "$s"; fi
}
PAYLOAD="$(json_payload "$MSG")"

rc=0
# Allow space- or comma-separated URLs (DM to both bridges if you run both).
for base in ${URLS//,/ }; do
  base="${base%/}"
  endpoint="$base/session/$TENANT/send-self"
  if [ "$DRY" = 1 ]; then
    printf 'POST %s\n%s\n' "$endpoint" "$PAYLOAD"
    continue
  fi
  if command -v curl >/dev/null 2>&1; then
    out="$(curl -fsS -m 15 -X POST "$endpoint" \
      -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
      --data-binary "$PAYLOAD" 2>&1)" \
      && echo "compass notify: sent via ${base}" >&2 \
      || { echo "compass notify: send failed (${base}): $out" >&2; rc=1; }
  else
    echo "compass notify: curl not found" >&2; rc=1
  fi
done
exit "$rc"
