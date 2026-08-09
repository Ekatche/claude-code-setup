#!/usr/bin/env bash
# PostToolUse hook on Bash|Grep|WebFetch|mcp__.* — advisory when a tool call
# returns a large raw dump. Can't truncate after the fact (tool_response
# already reached the model) — injects a reminder to process via context-mode
# instead of carrying raw output forward, and to prefer structured file:line
# summaries next time. Non-blocking.

set -euo pipefail

THRESHOLD=200

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

resp=$(echo "$input" | jq -r '
  .tool_response
  | if type == "string" then .
    elif has("output") then .output
    elif has("stdout") then .stdout
    elif has("content") then (.content | tostring)
    else tostring
    end
' 2>/dev/null || echo "")

[ -z "$resp" ] && exit 0

lines=$(echo "$resp" | wc -l | tr -d ' ')

if [ "$lines" -gt "$THRESHOLD" ] 2>/dev/null; then
  msg="ℹ $tool_name a retourné $lines lignes brutes (seuil $THRESHOLD) — ça reste en mémoire permanente de la conversation. Pour la suite : résume/filtre via ctx_execute ou ctx_batch_execute (context-mode) plutôt que de garder le dump brut ; si tu dois juste répondre, cite juste les lignes pertinentes (file:line + court extrait)."
  jq -n --arg msg "$msg" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $msg
    }
  }'
fi

exit 0
