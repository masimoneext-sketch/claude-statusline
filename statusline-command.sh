#!/usr/bin/env bash
# Claude Code Status Line — Multi-line Dashboard with Icons
# Persists model info and always shows all lines (even after /clear)

STATE_FILE="/tmp/.claude-statusline-state"
input=$(cat)

# --- Extract fields (with fallback to empty) ---
model=$(echo "$input" | jq -r '.model.display_name // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rate_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rate_7d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- Persist model & rate limits (survive /clear) ---
if [ -n "$model" ] && [ -n "$model_id" ]; then
  {
    echo "MODEL=$model"
    echo "MODEL_ID=$model_id"
    [ -n "$ctx_size" ] && echo "CTX_SIZE=$ctx_size"
    [ -n "$rate_5h" ] && echo "RATE_5H=$rate_5h"
    [ -n "$rate_5h_reset" ] && echo "RATE_5H_RESET=$rate_5h_reset"
    [ -n "$rate_7d" ] && echo "RATE_7D=$rate_7d"
    [ -n "$rate_7d_reset" ] && echo "RATE_7D_RESET=$rate_7d_reset"
  } > "$STATE_FILE"
elif [ -f "$STATE_FILE" ]; then
  source "$STATE_FILE"
  [ -z "$model" ] && model="$MODEL"
  [ -z "$model_id" ] && model_id="$MODEL_ID"
  [ -z "$ctx_size" ] && ctx_size="$CTX_SIZE"
  [ -z "$rate_5h" ] && rate_5h="$RATE_5H"
  [ -z "$rate_5h_reset" ] && rate_5h_reset="$RATE_5H_RESET"
  [ -z "$rate_7d" ] && rate_7d="$RATE_7D"
  [ -z "$rate_7d_reset" ] && rate_7d_reset="$RATE_7D_RESET"
fi

# --- Defaults for missing values (show zeroed, not hidden) ---
: "${model:=Claude}"
: "${model_id:=--}"
: "${used:=0}"
: "${ctx_size:=200000}"
: "${input_tokens:=0}"
: "${output_tokens:=0}"
: "${cost_usd:=0}"

# --- Bright Colors ---
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
WHITE='\033[1;97m'
MAGENTA='\033[1;95m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
RED='\033[1;91m'
CYAN='\033[1;96m'
BLUE='\033[1;94m'

# --- Helpers ---
pick_color() {
  local val=$1
  if [ "$val" -ge 80 ]; then echo "$RED"
  elif [ "$val" -ge 50 ]; then echo "$YELLOW"
  else echo "$GREEN"
  fi
}

make_bar() {
  local pct=$1 width=${2:-20}
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  echo "$bar"
}

format_tokens() {
  local t=$1
  if [ "$t" -ge 1000000 ]; then
    printf "%.1fM" "$(echo "$t / 1000000" | bc -l)"
  elif [ "$t" -ge 1000 ]; then
    printf "%.1fk" "$(echo "$t / 1000" | bc -l)"
  else
    echo "$t"
  fi
}

time_until_reset() {
  local reset_ts=$1
  local now=$(date +%s)
  local diff=$(( reset_ts - now ))
  if [ "$diff" -le 0 ]; then echo "adesso"; return; fi
  local hours=$(( diff / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    printf "%dh %dm" "$hours" "$mins"
  else
    printf "%dm" "$mins"
  fi
}

# --- USD to EUR ---
USD_TO_EUR="0.91"

# === LINE 1: MODEL (always visible) ===
printf "🤖 ${MAGENTA}${BOLD}%s${RST} ${DIM}(%s)${RST}\n" "$model" "$model_id"

# === LINE 2: CONTEXT WINDOW (zeroed after clear) ===
used_int=$(printf '%.0f' "$used")
ctx_color=$(pick_color "$used_int")
bar=$(make_bar "$used_int" 20)
ctx_label=" / $(format_tokens "$ctx_size")"
printf "📊 ${WHITE}Contesto${RST}  ${ctx_color}${bar} %d%%${RST}${DIM}%s${RST}\n" "$used_int" "$ctx_label"

# === LINE 3: TOKENS (zeroed after clear) ===
in_fmt=$(format_tokens "$input_tokens")
out_fmt=$(format_tokens "$output_tokens")
total=$(( input_tokens + output_tokens ))
total_fmt=$(format_tokens "$total")
printf "🔤 ${WHITE}Token${RST}     ${CYAN}↓ %s input${RST}  ${BLUE}↑ %s output${RST}  ${DIM}Σ %s${RST}\n" "$in_fmt" "$out_fmt" "$total_fmt"

# === LINE 4: COST (zeroed after clear) ===
cost_eur=$(echo "$cost_usd * $USD_TO_EUR" | bc -l 2>/dev/null)
usd_fmt=$(printf "%.4f" "$cost_usd")
eur_fmt=$(printf "%.4f" "${cost_eur:-0}")
if (( $(echo "$cost_usd >= 1.0" | bc -l 2>/dev/null || echo 0) )); then
  cost_color="$RED"
elif (( $(echo "$cost_usd >= 0.1" | bc -l 2>/dev/null || echo 0) )); then
  cost_color="$YELLOW"
else
  cost_color="$GREEN"
fi
printf "💶 ${WHITE}Costo${RST}     ${cost_color}\$ %s USD${RST}  →  ${cost_color}€ %s EUR${RST}\n" "$usd_fmt" "$eur_fmt"

# === LINE 5: RATE 5H (persisted across clear) ===
if [ -n "$rate_5h" ]; then
  r5_int=$(printf '%.0f' "$rate_5h")
  r5_color=$(pick_color "$r5_int")
  r5_bar=$(make_bar "$r5_int" 15)
  r5_reset=""
  if [ -n "$rate_5h_reset" ] && [ "$rate_5h_reset" != "null" ]; then
    r5_reset="  ⏳ reset $(time_until_reset "$rate_5h_reset")"
  fi
  printf "⚡ ${WHITE}Rate 5h${RST}   ${r5_color}${r5_bar} %d%%${RST}${DIM}%s${RST}\n" "$r5_int" "$r5_reset"
else
  printf "⚡ ${WHITE}Rate 5h${RST}   ${DIM}░░░░░░░░░░░░░░░ --%%  in attesa...${RST}\n"
fi

# === LINE 6: RATE 7D (persisted across clear) ===
if [ -n "$rate_7d" ]; then
  r7_int=$(printf '%.0f' "$rate_7d")
  r7_color=$(pick_color "$r7_int")
  r7_bar=$(make_bar "$r7_int" 15)
  r7_reset=""
  if [ -n "$rate_7d_reset" ] && [ "$rate_7d_reset" != "null" ]; then
    r7_reset="  ⏳ reset $(time_until_reset "$rate_7d_reset")"
  fi
  printf "📅 ${WHITE}Rate 7d${RST}   ${r7_color}${r7_bar} %d%%${RST}${DIM}%s${RST}\n" "$r7_int" "$r7_reset"
else
  printf "📅 ${WHITE}Rate 7d${RST}   ${DIM}░░░░░░░░░░░░░░░ --%%  in attesa...${RST}\n"
fi
