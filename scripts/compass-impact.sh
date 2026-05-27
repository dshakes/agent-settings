#!/usr/bin/env bash
# compass-impact.sh — "how is compass benefiting me?"
#
# Reads the best-effort local ledgers and prints a benefit dashboard:
#   🛡  footguns blocked   (disasters the guardrail stopped)
#   🧹  files auto-formatted (lint round-trips you didn't do)
#   💰  spend by model + estimated $ saved vs running everything on Opus
#
# Ledgers (written by the hooks + orchestrate.sh / compass onboard|schedule):
#   ${COMPASS_HOME:-~/.compass}/metrics.tsv   ts<TAB>event<TAB>repo<TAB>detail
#   ${COMPASS_HOME:-~/.compass}/spend.tsv      ts<TAB>repo<TAB>task<TAB>model<TAB>cost_usd
set -euo pipefail

HOME_DIR="${COMPASS_HOME:-$HOME/.compass}"
M="$HOME_DIR/metrics.tsv"; S="$HOME_DIR/spend.tsv"
WINDOW=all; JSON=0
usage(){ echo "usage: compass impact [--week|--all] [--json]"; }
for a in "$@"; do case "$a" in
  --week) WINDOW=week ;; --all) WINDOW=all ;; --json) JSON=1 ;;
  -h|--help) usage; exit 0 ;; *) usage; exit 2 ;;
esac; done

if [ -t 1 ] && [ "$JSON" = 0 ]; then
  B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; P=$'\033[35m'; C=$'\033[36m'; X=$'\033[0m'
else B=""; D=""; G=""; Y=""; R=""; P=""; C=""; X=""; fi

# Window cutoff (ISO date; lexical compare works on ISO timestamps).
cutoff="0000-00-00"
if [ "$WINDOW" = week ]; then
  cutoff="$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null || echo 0000-00-00)"
fi

# --- metrics: blocks + formats ---
blocks=0; formats=0
if [ -f "$M" ]; then
  read -r blocks formats <<EOF
$(awk -F'\t' -v c="$cutoff" '$1>=c{if($2=="block")b++;else if($2=="format")f++} END{printf "%d %d", b+0, f+0}' "$M" 2>/dev/null || echo "0 0")
EOF
fi

# --- spend: total + by model + estimated savings vs all-Opus ---
# Rough price ratios vs Opus per token: Sonnet ~1/5, Haiku ~1/18. Savings = the delta
# you avoided by NOT running that work on Opus. Clearly an ESTIMATE.
spend_out=""
if [ -f "$S" ]; then
  spend_out="$(awk -F'\t' -v c="$cutoff" '
    $1>=c {
      cost=$5+0; total+=cost; m=$4
      if(m=="haiku"){h+=cost} else if(m=="sonnet"){s+=cost} else if(m=="opus"){o+=cost} else {x+=cost}
    }
    END{
      saved = s*4 + h*17
      printf "%.4f|%.4f|%.4f|%.4f|%.4f|%.4f", total+0, h+0, s+0, o+0, x+0, saved+0
    }' "$S" 2>/dev/null || echo "0|0|0|0|0|0")"
fi
IFS='|' read -r t_total t_haiku t_sonnet t_opus t_other t_saved <<EOF
${spend_out:-0|0|0|0|0|0}
EOF

if [ "$JSON" = 1 ]; then
  printf '{"window":"%s","footguns_blocked":%s,"files_formatted":%s,"spend_usd":%s,"by_model":{"haiku":%s,"sonnet":%s,"opus":%s,"other":%s},"estimated_saved_vs_all_opus_usd":%s}\n' \
    "$WINDOW" "${blocks:-0}" "${formats:-0}" "${t_total:-0}" "${t_haiku:-0}" "${t_sonnet:-0}" "${t_opus:-0}" "${t_other:-0}" "${t_saved:-0}"
  exit 0
fi

win_label="all time"; [ "$WINDOW" = week ] && win_label="last 7 days"
echo
echo "  ${B}🧭 compass · impact${X}  ${D}($win_label)${X}"
echo "  ${D}────────────────────────────────────────${X}"
if [ ! -f "$M" ] && [ ! -f "$S" ]; then
  echo "  ${D}No activity logged yet. Use compass in a repo (guardrails + format hooks log"
  echo "  automatically) and run the SDLC pipeline / onboard, then check back.${X}"; echo; exit 0
fi
printf "  ${R}🛡  %-4s${X} footguns blocked        ${D}rm -rf, secret writes, force-push…${X}\n" "${blocks:-0}"
printf "  ${G}🧹  %-4s${X} files auto-formatted    ${D}lint round-trips you skipped${X}\n" "${formats:-0}"
if [ "$(awk "BEGIN{print ($t_total>0)}" 2>/dev/null)" = 1 ]; then
  printf "  ${C}💰  \$%-6s${X} agent spend           ${D}haiku \$%s · sonnet \$%s · opus \$%s${X}\n" \
    "$(printf '%.2f' "$t_total")" "$(printf '%.2f' "$t_haiku")" "$(printf '%.2f' "$t_sonnet")" "$(printf '%.2f' "$t_opus")"
  printf "  ${P}📉  ~\$%-5s${X} est. saved            ${D}vs running all that work on Opus (estimate)${X}\n" \
    "$(printf '%.2f' "$t_saved")"
fi
echo
echo "  ${D}Cost detail: compass spend · all opt-in, logged locally to ~/.compass${X}"
echo
