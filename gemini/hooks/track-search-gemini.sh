#!/usr/bin/env bash
# AfterTool — port agy de track-search.sh. Écrit dans le MÊME journal que le
# harnais Claude, avec le même schéma de ligne : c'est ce partage qui fait
# qu'un mgrep sous agy compte comme appel supérieur sous Claude.
set -uo pipefail

STATE_DIR="${HOME}/.claude/state"
LOG_FILE="${STATE_DIR}/search_log.jsonl"
mkdir -p "$STATE_DIR"; touch "$LOG_FILE"

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
[ "$tool" = "run_shell_command" ] || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
ts=$(date +%s)
tier=""

if printf '%s' "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*mgrep([[:space:]]|$)'; then
  if printf '%s' "$cmd" | grep -qE '\-\-web'; then tier='"web"'; else tier=1; fi
elif printf '%s' "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(tvly|firecrawl)([[:space:]]|$)'; then
  tier='"web"'
elif printf '%s' "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(ast-grep|sg)([[:space:]]|$)'; then
  tier=3
elif printf '%s' "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(rtk[[:space:]]+)?(grep|rg|egrep|fgrep)([[:space:]]|$)'; then
  tier=4
else
  exit 0
fi

jq -nc --arg ts "$ts" --argjson tier "$tier" --arg cmd "$cmd" --arg sid "$session" \
  '{ts: ($ts|tonumber), tier: $tier, tool: "run_shell_command", session_id: $sid, cmd: $cmd, harness: "agy"}' \
  >> "$LOG_FILE"
exit 0
