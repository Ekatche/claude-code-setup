#!/usr/bin/env bash
# BeforeAgent — port agy de search-rule-reminder.sh.
# Réinjecte la hiérarchie à chaque tour ET pose le marqueur de début de tour
# dont block-grep-search-gemini.sh a besoin : sans ce marqueur, le gate
# accepterait une recherche faite dans un tour précédent sans rapport.
set -uo pipefail

STATE_DIR="${HOME}/.claude/state"
mkdir -p "$STATE_DIR"
input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
date +%s > "${STATE_DIR}/turn_start.${session}.txt" 2>/dev/null || true

ctx='RAPPEL — choix d'"'"'outil par COMPÉTENCE, pas par prix.

CODE :
  • Question sémantique en langage naturel : mgrep '"'"'<question>'"'"'   [1er choix]
  • Motif structurel, forme de code        : sg -p '"'"'<motif>'"'"' -l <lang>  (seul capable)
  • Structure d'"'"'un fichier              : sg outline -l <lang> <fichier>  (zéro lecture intégrale)
  • Texte littéral exact                   : rtk grep, après un appel supérieur.
    grep/rg/find bruts sont BLOQUÉS sinon — la commande n'"'"'est pas exécutée.

Ne lis jamais un fichier entier pour y chercher quelque chose : localise, puis lis la zone.

FORMAT DE SORTIE : retour structuré (fichier:ligne + court extrait) plutôt que dump brut ;
plusieurs questions en un seul appel plutôt qu'"'"'une série d'"'"'appels.'

jq -nc --arg c "$ctx" \
  '{hookSpecificOutput: {hookEventName: "BeforeAgent", additionalContext: $c}}'
exit 0
