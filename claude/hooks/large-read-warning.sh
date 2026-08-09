#!/usr/bin/env bash
# PreToolUse hook on Read — HARD BLOCK si fichier > 500 lignes lu sans offset/limit.
#
# Mutated 2026-07-10 from "warn-only" (seuil 1000, non-bloquant) à "hard block"
# (seuil 500) : la discipline manuelle "Read ciblé" ne suffisait pas, cf.
# CLAUDE.md global point "Read ciblé — jamais de Read full sans raison".
# Backup: large-read-warning.sh.warn-only.bak.20260710
#
# Pas de bypass marker (contrairement à block-grep-search.sh) : le tool Read
# natif n'a pas de champ commentaire. Bypass = juste refaire l'appel avec
# offset/limit, ou lire par petits morceaux.

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
offset=$(echo "$input" | jq -r '.tool_input.offset // empty')
limit=$(echo "$input" | jq -r '.tool_input.limit // empty')

# Skip if file doesn't exist locally (let Read handle the error)
if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  exit 0
fi

# Skip image/PDF/notebook (Read handles them specially, line count meaningless)
case "$file_path" in
  *.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.ipynb)
    exit 0
    ;;
esac

# offset or limit already set → caller is already targeting, allow
if [ -n "$offset" ] || [ -n "$limit" ]; then
  exit 0
fi

lines=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ')
[ -z "$lines" ] && exit 0

THRESHOLD=500

if [ "$lines" -gt "$THRESHOLD" ] 2>/dev/null; then
  msg="🚫 BLOQUÉ — Read sans offset/limit sur $file_path ($lines lignes, seuil $THRESHOLD).

GRATUIT, toujours disponible — commence par là :
  • Bash : ast-grep outline -l <lang> $file_path   (structure du fichier :
                                            symboles, imports, exports, membres)
  • mcp__token-savior__find_symbol         (localiser un symbole, puis Read ciblé)
  • mcp__token-savior__get_function_source (source d'UNE fonction, pas du fichier)
  • Read avec offset+limit sur la zone identifiée
  • ctx_execute_file (context-mode) si tu veux juste analyser/résumer :
    seul ce que tu log entre en contexte, les octets bruts restent au sandbox

SI LE PROJET A UN GRAPHE (MCP project-scope, absent hors de ces projets) :
  • mcp__code-review-graph__get_review_context_tool
  • mcp__code-review-graph__semantic_search_nodes_tool

PAYANT — quand le gratuit n'a rien donné :
  • Bash : mgrep '<query>'                 (localise la zone, puis Read précis)

DERNIER RECOURS — le fichier entier est réellement nécessaire (petit config,
lecture exhaustive justifiée) : refais l'appel avec limit=$lines pour l'assumer
explicitement."

  jq -n --arg msg "$msg" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $msg
    }
  }'
fi

exit 0
