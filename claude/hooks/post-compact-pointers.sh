#!/usr/bin/env bash
# SessionStart hook, matcher "compact" — ne se déclenche qu'après un auto-compact
# ou un /compact manuel. stdout est réinjecté dans le contexte de Claude.
#
# Réinjecte des POINTEURS vers l'état, jamais l'état lui-même : le compact vient
# de résumer parce que le contexte était plein, le remplir à nouveau avec du
# contenu annulerait le bénéfice. Un chemin de fichier de plan coûte 20 tokens,
# son contenu 5000 — et Claude peut relire le fichier s'il en a besoin.
#
# Voir ~/.claude/CONTEXT.md, section "Auto-compact".

set -euo pipefail

echo "CONTEXTE VENANT D'ÊTRE COMPACTÉ — le détail a été résumé, pas conservé."
echo "Avant de continuer, récupère l'état depuis le disque :"
echo
echo "  1. ctx_search(queries: [\"<le sujet en cours>\"], sort: \"timeline\")"
echo "     Décisions, erreurs, plans et prompts utilisateur de cette session"
echo "     sont indexés et survivent au compact. Interroge-les AVANT de"
echo "     redemander quoi que ce soit à l'utilisateur."
echo
echo "  2. Fichier de plan actif — s'il y en a un, c'est lui l'état de vérité,"
echo "     pas ta liste de tâches affichée. Relis-le avant de reprendre."

# Plans récents dans le cwd (pointeur + statut, jamais le contenu).
# micro-dev : docs/micro/<date>-<slug>/PLAN.md ; superpowers:writing-plans :
# docs/superpowers/plans/*.md.
recent=$(ls -t ./docs/micro/*/PLAN.md ./docs/superpowers/plans/*.md 2>/dev/null | head -n 3 || true)
if [ -n "$recent" ]; then
  echo
  echo "     Plans les plus récents ici :"
  while IFS= read -r p; do
    st=$(sed -n 's/^status:[[:space:]]*//p' "$p" | head -n 1)
    echo "       $p${st:+  [status: $st]}"
  done <<< "$recent"
fi

echo
echo "  3. Faits durables : ~/.claude/MEMORY.md (index, une ligne par fait)."
echo
echo "  4. Contrat mémoire, hiérarchie de recherche et règles de lecture :"
echo "     ~/.claude/CONTEXT.md — toujours en vigueur, relis-le si tu hésites"
echo "     sur quel outil utiliser."

echo
echo "Règle qui a mené ici : l'état vit sur disque, jamais uniquement dans le"
echo "contexte. Avant la prochaine opération longue (fan-out de subagents,"
echo "boucle de build, exploration large), écris l'état courant dans le plan."

exit 0
