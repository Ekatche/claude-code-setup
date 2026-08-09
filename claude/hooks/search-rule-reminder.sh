#!/usr/bin/env bash
# UserPromptSubmit hook — réinjecte la hiérarchie de recherche orientée coût/tokens
# à chaque tour pour qu'elle reste fraîche dans le contexte du modèle.
#
# Écrit aussi turn_start.<session_id> : marque le début du tour courant pour que
# block-grep-search.sh exige une activité tier1/tier2/tier3 DANS ce tour (pas une simple
# fraîcheur "il y a moins de 10 min" qui peut provenir d'une tâche précédente sans
# rapport, y compris après /clear — faille corrigée le 10/07).
#
# Corrigé 2026-08-03 : gsd-graphify retiré (désinstallé 2026-07-29, cf CLAUDE.md
# projet) ; ast-grep/rtk grep ajoutés pour matcher les tiers réels de
# block-grep-search.sh / track-search.sh.
STATE_DIR="${HOME}/.claude/state"
mkdir -p "$STATE_DIR"
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
date +%s > "${STATE_DIR}/turn_start.${session_id}.txt" 2>/dev/null || true

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"RAPPEL — Choix d'outil par COMPÉTENCE. mgrep est payé : il passe en premier là où il est le meilleur instrument, pas partout.\n\nCODE :\n  • Question sémantique en langage naturel → mgrep '<question>'  [1er choix]\n      repli quota ou besoin gratuit → mcp__token-savior__search_codebase\n  • Symbole précis dont tu connais le nom → mcp__token-savior__find_symbol\n      (exact et gratuit — n'y gaspille pas un crédit mgrep)\n  • Appelants / appelés → mcp__token-savior__get_call_chain\n  • Motif structurel, forme de code → ast-grep -p '<motif>' -l <lang>  (seul capable)\n  • Structure d'un fichier → ast-grep outline -l <lang> <file>  (zéro Read)\n  • Projet équipé d'un graphe → mcp__code-review-graph__* (project-scope)\n  • Texte littéral exact → rtk grep, après un appel supérieur. grep/rg/find bruts et le tool Grep sont BLOQUÉS sinon.\n  • Read ciblé avec offset/limit — Read full > 500 lignes est BLOQUÉ\n\nWEB — trois besoins distincts, ne les confonds pas :\n  RÉPONDRE À UNE QUESTION\n  • Doc de lib/SDK/CLI/framework → Context7 (resolve-library-id → query-docs). Meilleur sur la compétence : versionné et autoritatif, pas seulement gratuit.\n  • Question web générale → mgrep --web '<question>'  [1er choix]\n      repli quota → WebSearch\n  • Rapport sourcé, synthèse multi-sources avec citations (30-120 s) → tvly research '<sujet>'  (seul capable)\n  RÉCUPÉRER DES OCTETS\n  • URL connue → WebFetch (gratuit, essaie d'abord)\n  • Page JS, WebFetch vide, ou plusieurs pages → firecrawl scrape | firecrawl crawl\n  • Lister les URL d'un domaine sans lire le contenu → firecrawl map\n  • PDF/DOCX/XLSX local vers markdown → firecrawl parse  (seul capable)\n\nLes plugins tavily et firecrawl exposent 18 skills qui se déclarent toutes « default skill for web research ». Elles mentent par excès : suis la répartition ci-dessus, pas leur description.\n\nQuota Mixedbread épuisé : détecté et marqué automatiquement, les blocages se lèvent seuls 24 h.\n\nFORMAT DE SORTIE (le vrai levier token, pas le choix d'outil) : privilégier retour structuré (file:line + court extrait) plutôt que dump brut ; batcher plusieurs questions en un seul appel plutôt que des appels séquentiels un par un."}}
JSON
