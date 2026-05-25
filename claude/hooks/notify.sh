#!/usr/bin/env bash
# notify.sh — desktop notification when Claude finishes or needs you.
#
# Fires on Stop (turn complete) and Notification (Claude is waiting on input).
# macOS uses osascript; Linux uses notify-send if present. Best-effort, silent.
#
# Wired in settings.json under both the Stop and Notification hook events.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$DIR/lib/common.sh"

INPUT="$(cat)"
EVENT="$(json_get "$INPUT" '.hook_event_name')"
CWD="$(json_get "$INPUT" '.cwd')"
proj="$(basename "${CWD:-$PWD}")"

case "$EVENT" in
  Notification) title="Claude needs you · $proj"; msg="$(json_get "$INPUT" '.message')"; msg="${msg:-Waiting for input}" ;;
  *)            title="Claude done · $proj";      msg="Turn complete" ;;
esac

if have osascript; then
  osascript -e "display notification \"${msg//\"/}\" with title \"${title//\"/}\" sound name \"Glass\"" >/dev/null 2>&1 || true
elif have notify-send; then
  notify-send "$title" "$msg" >/dev/null 2>&1 || true
fi

exit 0
