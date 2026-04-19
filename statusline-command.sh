#!/bin/bash
input=$(cat)
user="BIG_BOSS"

# Cores
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
CYAN="\033[01;36m"
RESET="\033[0m"

ps1_part=$(printf "${GREEN}%s${RESET}" "$user")

# Extract fields using jq
MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# ===== Progress Bar =====
BAR_WIDTH=20
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))

BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

# ===== Cost / Duration =====
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

MINS=$((DURATION_MS / 60000)) 
SECS=$(((DURATION_MS % 60000) / 1000))

# ===== Rate Limits =====
FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.reset_in_seconds // empty')

WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.reset_in_seconds // empty')

format_time() {
  local T=$1
  local H=$((T / 3600))
  local M=$(((T % 3600) / 60))
  local S=$((T % 60))
  printf "%02dh %02dm %02ds" "$H" "$M" "$S"
}

LIMITS=""

if [ -n "$FIVE_H_PCT" ]; then
  RESET_5H=""
  [ -n "$FIVE_H_RESET" ] && RESET_5H="($(format_time $FIVE_H_RESET))"
  LIMITS="5h: $(printf '%.0f' "$FIVE_H_PCT")% $RESET_5H"
fi

if [ -n "$WEEK_PCT" ]; then
  RESET_7D=""
  [ -n "$WEEK_RESET" ] && RESET_7D="($(format_time $WEEK_RESET))"
  LIMITS="${LIMITS:+$LIMITS | }7d: $(printf '%.0f' "$WEEK_PCT")% $RESET_7D"
fi

# ===== Output =====
printf "%b\n" "${ps1_part} 📁 ${CYAN}${DIR##*/}${RESET}"
printf "%b\n" "${YELLOW}${MODEL}${RESET} ${BAR} ${PCT}% context | R$ ${COST} | ⏱️ ${MINS}m ${SECS}s"
printf "%b\n" "${LIMITS}"
