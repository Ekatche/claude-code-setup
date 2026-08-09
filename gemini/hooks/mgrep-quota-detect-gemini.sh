#!/usr/bin/env bash
# AfterTool — port agy de mgrep-quota-detect.sh. Marque le quota épuisé dans
# le MÊME fichier d'état que le harnais Claude : le quota appartient au
# compte Mixedbread, pas au harnais qui l'a constaté.
set -uo pipefail

STATE_DIR="${HOME}/.claude/state"
QUOTA_FILE="${STATE_DIR}/mgrep_quota.json"
mkdir -p "$STATE_DIR"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
printf '%s' "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*mgrep([[:space:]]|$)' || exit 0

out=$(printf '%s' "$input" | jq -r '.tool_response.llmContent // .tool_response.output // ""' 2>/dev/null || echo "")
if printf '%s' "$out" | grep -qiE 'quota|out of credits|insufficient credits|payment required|402'; then
  jq -nc --arg ts "$(date +%s)" '{exhausted: true, ts: ($ts|tonumber), source: "agy"}' > "$QUOTA_FILE"
  jq -nc '{hookSpecificOutput: {hookEventName: "AfterTool", additionalContext: "Quota Mixedbread marqué épuisé. Les blocages se lèvent seuls pendant 24 h — utilise les outils gratuits, ne contourne pas."}}'
fi
exit 0
