#!/usr/bin/env bash
# UserPromptSubmit hook — rappelle /compact tous les 25 messages utilisateur.
#
# Compte par session (fichier state/compact_count.<session_id>.txt), reset au
# /clear (nouveau session_id). Rappel répété tous les 25 messages, pas juste
# une fois — sessions qui continuent longtemps après le premier rappel ignoré.

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
mkdir -p "$STATE_DIR"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
[ "$session_id" = "unknown" ] && exit 0

COUNT_FILE="${STATE_DIR}/compact_count.${session_id}.txt"
count=$(cat "$COUNT_FILE" 2>/dev/null || echo "0")
count=$((count + 1))
echo "$count" > "$COUNT_FILE"

THRESHOLD=25

if [ $((count % THRESHOLD)) -eq 0 ]; then
  msg="Session à $count messages. Envisage /compact proactif — résumé plus fidèle qu'un snapshot rescue à la limite dure."
  jq -n --arg msg "$msg" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $msg
    }
  }'
fi

exit 0
