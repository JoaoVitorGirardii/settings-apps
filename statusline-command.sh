#!/bin/bash
input=$(cat)
user=$(whoami)

# Cores
GREEN="\033[01;32m"
RED="\033[01;31m"
WHITE="\033[01;37m"
YELLOW="\033[01;33m"
CYAN="\033[01;36m"
MAGENTA="\033[01;35m"
BLUE="\033[01;34m"
RESET="\033[0m"

ps1_part=$(printf "${GREEN}%s${RESET} ${WHITE}@${RESET} " "$user")

# Extract fields using jq
MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')

# ===== Model line (top) =====
CLR_MODEL="\033[01;38;5;75m"   # azul cornflower bold
CLR_EFFORT="\033[38;5;114m"    # verde sage
CLR_DIR="\033[38;5;183m"       # lavanda
CLR_BRANCH="\033[38;5;215m"    # pêssego/laranja claro

MODEL_LINE="${CLR_MODEL}${MODEL}${RESET}"
if [ -n "$EFFORT" ]; then
  MODEL_LINE="${MODEL_LINE}${WHITE}[${RESET}${CLR_EFFORT}${EFFORT}${WHITE}]${RESET}"
fi

# ===== Progress Bar =====
BAR_WIDTH=20

ctx_color() {
  local p=$1
  local step=$((p / 5))
  [ "$step" -gt 20 ] && step=20
  case $step in
    0)  printf "\033[38;5;238m" ;;  # 0%   cinza escuro
    1)  printf "\033[38;5;240m" ;;  # 5%
    2)  printf "\033[38;5;242m" ;;  # 10%
    3)  printf "\033[38;5;244m" ;;  # 15%
    4)  printf "\033[38;5;246m" ;;  # 20%
    5)  printf "\033[38;5;248m" ;;  # 25%
    6)  printf "\033[38;5;250m" ;;  # 30%
    7)  printf "\033[38;5;252m" ;;  # 35%
    8)  printf "\033[38;5;255m" ;;  # 40%  branco
    9)  printf "\033[38;5;226m" ;;  # 45%  amarelo vivo
    10) printf "\033[38;5;220m" ;;  # 50%  amarelo-laranja
    11) printf "\033[38;5;214m" ;;  # 55%  laranja
    12) printf "\033[38;5;208m" ;;  # 60%  laranja escuro
    13) printf "\033[38;5;202m" ;;  # 65%  laranja-vermelho
    14) printf "\033[38;5;196m" ;;  # 70%  vermelho
    15) printf "\033[38;5;160m" ;;  # 75%  vermelho médio
    16) printf "\033[38;5;124m" ;;  # 80%  vermelho escuro
    17) printf "\033[01;38;5;196m" ;;  # 85%  vermelho vivo bold
    18) printf "\033[01;38;5;196m" ;;  # 90%  vermelho vivo bold
    19) printf "\033[01;38;5;196m" ;;  # 95%  vermelho vivo bold
    20) printf "\033[01;38;5;196m" ;;  # 100% vermelho vivo bold
  esac
}

make_bar() {
  local RAW_PCT=$1
  local INT_PCT=$(printf '%.0f' "$RAW_PCT")
  [ "$INT_PCT" -gt 100 ] && INT_PCT=100
  local F=$((INT_PCT * BAR_WIDTH / 100))
  local E=$((BAR_WIDTH - F))
  local B=""
  [ "$F" -gt 0 ] && printf -v _FILL "%${F}s" && B="${_FILL// /█}"
  [ "$E" -gt 0 ] && printf -v _PAD "%${E}s" && B="${B}${_PAD// /░}"
  printf "%s" "$B"
}

CTX_BAR=$(make_bar "$PCT")

# ===== Rate Limits =====
NOW=$(date +%s)

FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESETS_AT=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESETS_AT=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

format_remaining() {
  local EPOCH=$1
  local DIFF=$(( EPOCH - NOW ))
  [ "$DIFF" -lt 0 ] && DIFF=0
  local D=$((DIFF / 86400))
  local H=$(((DIFF % 86400) / 3600))
  local M=$(((DIFF % 3600) / 60))
  if [ "$D" -gt 0 ]; then
    printf "%dd%dh" "$D" "$H"
  else
    printf "%dh%02dm" "$H" "$M"
  fi
}

LIMIT_5H=""
LIMIT_7D=""

if [ -n "$FIVE_H_PCT" ]; then
  RESET_5H=""
  [ -n "$FIVE_H_RESETS_AT" ] && RESET_5H=" - $(format_remaining "$FIVE_H_RESETS_AT")"
  FBAR=$(make_bar "$FIVE_H_PCT")
  LIMIT_5H="\033[38;5;131m${FBAR}${RESET} $(printf '%.0f' "$FIVE_H_PCT")%${RESET_5H}"
fi

if [ -n "$WEEK_PCT" ]; then
  RESET_7D=""
  [ -n "$WEEK_RESETS_AT" ] && RESET_7D=" - $(format_remaining "$WEEK_RESETS_AT")"
  WBAR=$(make_bar "$WEEK_PCT")
  LIMIT_7D="\033[38;5;179m${WBAR}${RESET} $(printf '%.0f' "$WEEK_PCT")%${RESET_7D}"
fi

# ===== Git branch (skip optional locks) =====
GIT_BRANCH=$(GIT_OPTIONAL_LOCKS=0 git -C "$DIR" symbolic-ref --short HEAD 2>/dev/null)
GIT_PART=""
[ -n "$GIT_BRANCH" ] && GIT_PART=" ${CLR_BRANCH} ${GIT_BRANCH}${RESET}"

# ===== Output =====
# Line 1: model + effort + user @ dir + git
printf "%b\n" "${MODEL_LINE} ${WHITE}·${RESET} ${CLR_DIR}${DIR##*/}${RESET}${GIT_PART}"
# Lines 3+: aligned bars (label = 3 chars, space, then bar)
CTX_COLOR=$(ctx_color "$PCT")
printf "%b\n" "ctx ${CTX_COLOR}${CTX_BAR}${RESET} ${PCT}%"
[ -n "$LIMIT_5H" ] && printf "%b\n" "5h  ${LIMIT_5H}"
[ -n "$LIMIT_7D" ] && printf "%b\n" "7d  ${LIMIT_7D}"
