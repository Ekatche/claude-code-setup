#!/usr/bin/env bash
# BeforeTool (matcher run_shell_command) — port agy de block-grep-search.sh.
#
# Contrat Gemini/Antigravity : {"decision":"deny","reason":"..."} bloque
# l'appel et renvoie `reason` au modèle comme erreur d'outil.
#
# L'état est PARTAGÉ avec le harnais Claude : même search_log.jsonl, même
# marqueur de début de tour. Un mgrep lancé sous agy lève donc le gate sous
# Claude, et réciproquement. C'est voulu : le quota et la hiérarchie
# appartiennent au compte, pas au harnais.
set -uo pipefail

STATE_DIR="${HOME}/.claude/state"
LOG_FILE="${STATE_DIR}/search_log.jsonl"
mkdir -p "$STATE_DIR"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# Rien à faire si ce n'est pas une recherche littérale brute.
if ! printf '%s' "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(grep|rg|egrep|fgrep)([[:space:]]|$)' \
   && ! printf '%s' "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*find[[:space:]].*-(name|iname|regex|path)'; then
  exit 0
fi

# rtk grep est la forme autorisée, pas la forme bloquée.
if printf '%s' "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*rtk[[:space:]]+grep([[:space:]]|$)'; then
  exit 0
fi

turn_file="${STATE_DIR}/turn_start.${session}.txt"
turn_start=0
[ -f "$turn_file" ] && turn_start=$(cat "$turn_file" 2>/dev/null || echo 0)

superior=0
if [ -f "$LOG_FILE" ]; then
  superior=$(tail -n 200 "$LOG_FILE" 2>/dev/null \
    | jq -r --argjson cut "$turn_start" \
      'select(.ts >= $cut and ((.tier|tostring) == "1" or (.tier|tostring) == "2" or (.tier|tostring) == "3")) | .ts' \
      2>/dev/null | wc -l | tr -d ' ')
fi

if [ "${superior:-0}" -gt 0 ]; then
  exit 0
fi

reason='BLOQUÉ — grep/rg/find brut sans appel de tier supérieur dans ce tour.

Choisis selon le BESOIN, pas selon le prix :
  • Question sémantique en langage naturel : mgrep '"'"'<question>'"'"'   [1er choix]
  • Motif structurel, forme de code       : sg -p '"'"'<motif>'"'"' -l <lang>  (seul capable)
  • Structure d'"'"'un fichier             : sg outline -l <lang> <fichier>
  • Texte littéral exact, après l'"'"'un des précédents : rtk grep '"'"'<texte>'"'"' <chemin>

Quota mgrep épuisé : détecté automatiquement, les blocages se lèvent seuls 24 h.'

jq -nc --arg r "$reason" '{decision: "deny", reason: $r}'
exit 0
