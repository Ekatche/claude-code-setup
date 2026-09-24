#!/usr/bin/env bash
# UserPromptSubmit hook — rappelle /compact quand le contexte approche du seuil
# d'auto-compact, mesuré en tokens réels et non en nombre de messages : un seul
# gros tool result pèse plus que 25 prompts courts.
#
# Tokens = usage du dernier message assistant du thread principal dans le
# transcript (input + cache_creation + cache_read). Seuil =
# CLAUDE_CODE_AUTO_COMPACT_WINDOW, même valeur absolue pour tous les modèles
# (cf. ~/.claude/CONTEXT.md § Auto-compact). Variable absente : pas de rappel.
#
# Deux paliers, 70 % puis 90 % du seuil, un rappel chacun. Réarmé quand le
# contexte redescend sous la moitié du seuil (après un compact).

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
mkdir -p "$STATE_DIR"

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
{ [ -n "$session_id" ] && [ -f "$transcript" ]; } || exit 0

window="${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}"
[[ "$window" =~ ^[0-9]+$ ]] || exit 0

# fromjson? : le transcript est écrit en asynchrone, la dernière ligne peut être
# incomplète.
used=$(tail -n 400 "$transcript" | jq -Rn '
  [inputs | fromjson? | select(.type == "assistant" and (.isSidechain | not))
   | .message.usage | select(.)
   | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)]
  | last // 0' 2>/dev/null || echo 0)

LEVEL_FILE="${STATE_DIR}/compact_reminded.${session_id}.txt"
reminded=$(cat "$LEVEL_FILE" 2>/dev/null || echo "0")

if [ "$used" -lt $((window / 2)) ]; then
  rm -f "$LEVEL_FILE"
  exit 0
fi

level=0
[ "$used" -ge $((window * 70 / 100)) ] && level=70
[ "$used" -ge $((window * 90 / 100)) ] && level=90
[ "$level" -gt "$reminded" ] || exit 0
echo "$level" > "$LEVEL_FILE"

msg="Contexte à ${used} tokens, auto-compact à ${window} (${level} % atteint). Propose à l'utilisateur un /compact <focus> à la prochaine frontière de tâche — un compact choisi garde mieux l'état qu'un auto-compact en pleine opération. Avant : écris l'état courant dans le fichier de plan."
jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $msg
  }
}'

exit 0
