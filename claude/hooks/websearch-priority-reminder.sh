#!/usr/bin/env bash
# PreToolUse hook on WebSearch — HARD BLOCK if no Context7 nor mgrep --web call in last 5 min.
#
# Mutated 2026-05-04 from "soft reminder" to "warn-then-deny": data showed 80 web calls
# vs 2 mgrep --web in 7 days. Backup: websearch-priority-reminder.sh.warn-only.bak.20260504
#
# Hierarchy enforced :
#   1. Context7 (mcp__context7__*) — GRATUIT, pour libs/SDK/frameworks
#
# Corrigé 2026-08-08 : le préfixe testé était mcp__plugin_context7_context7__*,
# qui n'existe pas — Context7 est un MCP user-scope, pas un plugin. Zéro entrée
# context7 sur 2000 lignes de search_log.jsonl. Effet : seul `mgrep --web`
# (payant) débloquait WebSearch, alors que le fichier déclare le gratuit en
# tête de hiérarchie. Le hook imposait exactement l'inverse de son intention.
# L'ancien préfixe est conservé dans le test au cas où un plugin Context7
# serait installé un jour.
#   2. mgrep --web (Bash mgrep --web '<query>') — crédits Mixedbread, sémantique
#   3. WebSearch natif Anthropic — fallback uniquement
#   4. WebFetch — URL connue uniquement
#
# Bypass : `[fallback]` ou `[justified: <raison>]` dans la query (loggé pour audit).
# Allow if : Context7 OR mgrep --web called in last 5 min.

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
LOG_FILE="${STATE_DIR}/search_log.jsonl"
BYPASS_LOG="${STATE_DIR}/search_bypass.jsonl"

input=$(cat)
query=$(echo "$input" | jq -r '.tool_input.query // ""')

# Bypass markers
if echo "$query" | grep -qiE '\[(fallback|justified[^]]*)\]'; then
  reason=$(echo "$query" | sed -nE 's/.*\[(fallback|justified[^]]*)\].*/\1/p')
  jq -nc \
    --arg ts "$(date +%s)" \
    --arg query "$query" \
    --arg reason "$reason" \
    '{ts: ($ts|tonumber), event: "websearch_bypass", query: $query, reason: $reason}' \
    >> "$BYPASS_LOG" 2>/dev/null || true
  exit 0
fi

# Check log for recent Context7 or mgrep --web activity (last 5 min)
if [ -f "$LOG_FILE" ]; then
  now=$(date +%s)
  cutoff=$(( now - 300 ))

  recent_context7=$(tail -n 200 "$LOG_FILE" 2>/dev/null \
    | jq -r --argjson cut "$cutoff" \
      'select(.ts >= $cut and ((.tool | startswith("mcp__context7__")) or (.tool | startswith("mcp__plugin_context7_context7__")))) | .ts' \
      2>/dev/null | wc -l | tr -d ' ')

  # mgrep --web, tvly ou firecrawl : trois outils web de compétence supérieure à
  # WebSearch natif. N'importe lequel dans les 5 min satisfait le gate — le hook
  # existe pour empêcher le réflexe WebSearch, pas pour imposer un fournisseur.
  recent_mgrep_web=$(tail -n 200 "$LOG_FILE" 2>/dev/null \
    | jq -r --argjson cut "$cutoff" \
      'select(.ts >= $cut and .tier == "web" and .tool == "Bash" and ((.cmd // "") | test("mgrep[[:space:]]+--web|(^|&&|;|\\|\\|)[[:space:]]*(tvly|firecrawl)([[:space:]]|$)"))) | .ts' \
      2>/dev/null | wc -l | tr -d ' ')

  # Quota Mixedbread épuisé (marqué par mgrep-quota-detect.sh, TTL 24 h) →
  # WebSearch devient le repli légitime, sans exiger un mgrep --web qui échouera.
  QUOTA_FILE="${STATE_DIR}/mgrep_quota.json"
  if [ -f "$QUOTA_FILE" ]; then
    q_ts=$(jq -r '.ts // 0' "$QUOTA_FILE" 2>/dev/null || echo 0)
    q_exhausted=$(jq -r '.exhausted // false' "$QUOTA_FILE" 2>/dev/null || echo false)
    if [ "$q_exhausted" = "true" ] && [ $(( now - q_ts )) -lt 86400 ] 2>/dev/null; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          additionalContext: "WebSearch autorisé — quota Mixedbread marqué épuisé (< 24 h). Pour une doc de lib/SDK, Context7 reste meilleur ET gratuit."
        }
      }'
      exit 0
    fi
  fi

  if [ "$recent_context7" -gt 0 ] || [ "$recent_mgrep_web" -gt 0 ]; then
    # Higher tier was tried, allow with light reminder
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: "WebSearch autorisé (tentative Context7 / mgrep --web / tvly / firecrawl récente détectée)."
      }
    }'
    exit 0
  fi
fi

# No higher-tier web search in last 5 min → DENY
msg="🚫 BLOQUÉ — WebSearch natif sans tentative d'un outil web supérieur (Context7,
mgrep --web, tvly, firecrawl) dans les 5 dernières minutes.

Choisis selon le BESOIN :
  • DOC D'UNE LIB / SDK / FRAMEWORK / CLI — Context7 gagne sur la compétence,
    pas seulement sur le prix : versionné, autoritatif, à jour.
      mcp__context7__resolve-library-id  (puis mcp__context7__query-docs)
  • RECHERCHE WEB GÉNÉRALE — mgrep --web passe en premier, l'abonnement est payé.
      Bash : mgrep --web '<question>'                      — crédits Mixedbread
  • RAPPORT SOURCÉ, synthèse multi-sources avec citations (30-120 s) — seul
    tavily sait faire :
      Bash : tvly research '<sujet>'
  • URL DÉJÀ CONNUE — WebFetch d'abord, c'est gratuit :
      WebFetch <url>
    Page en JavaScript, WebFetch revient vide, ou il faut plusieurs pages :
      Bash : firecrawl scrape <url>   |   firecrawl crawl <url>
  • DÉCOUVRIR LES URL d'un domaine sans en lire le contenu :
      Bash : firecrawl map <domaine>
  • FICHIER LOCAL PDF / DOCX / XLSX vers markdown — aucun autre outil ici ne
    le fait :
      Bash : firecrawl parse <fichier>

Quota Mixedbread épuisé ? mgrep-quota-detect.sh le marque automatiquement et ce
blocage se lève seul pendant 24 h. Pour forcer à la main :
  echo '{\"exhausted\":true,\"ts\":'\$(date +%s)'}' > ~/.claude/state/mgrep_quota.json

BYPASS LÉGITIME (aucun des outils ci-dessus ne couvre le besoin) :
  Préfixe la query avec \`[fallback]\` ou \`[justified: <raison>]\`.
  Exemple : query='[fallback] news article about X published yesterday'

Le bypass est loggé dans ~/.claude/state/search_bypass.jsonl pour audit."

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $msg
  }
}'
exit 0
