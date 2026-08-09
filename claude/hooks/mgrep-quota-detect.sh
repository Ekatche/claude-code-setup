#!/usr/bin/env bash
# PostToolUse hook on Bash — détecte l'épuisement du quota Mixedbread et le marque
# sur disque pour que les hooks de recherche autorisent le repli vers le gratuit.
#
# Raison d'être : la hiérarchie de cette machine met mgrep en PREMIER sur les
# besoins sémantiques (l'abonnement est payé, il doit servir). Ce choix n'a de
# sens que s'il existe un repli automatique quand les crédits sont épuisés —
# sinon la première recherche après épuisement bloque le travail.
#
# État écrit : ~/.claude/state/mgrep_quota.json
#   {"exhausted": true, "ts": 1754680000, "evidence": "<ligne déclenchante>"}
#
# Expiration : QUOTA_TTL secondes (24 h). Les quotas se rechargent ; un marqueur
# permanent ferait taire mgrep pour toujours après un seul incident.
#
# Réinitialisation manuelle : rm ~/.claude/state/mgrep_quota.json

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
QUOTA_FILE="${STATE_DIR}/mgrep_quota.json"
mkdir -p "$STATE_DIR"

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

# Ne concerne que les appels mgrep
echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*mgrep([[:space:]]|$)' || exit 0

resp=$(echo "$input" | jq -r '
  .tool_response
  | if type == "string" then .
    elif has("output") then .output
    elif has("stderr") then ((.stdout // "") + "\n" + .stderr)
    elif has("stdout") then .stdout
    else tostring
    end
' 2>/dev/null || echo "")

[ -z "$resp" ] && exit 0

# Motifs d'épuisement. Volontairement larges : un faux positif coûte un repli
# vers un outil gratuit pendant 24 h, un faux négatif bloque le travail.
pattern='quota|out of credits|insufficient credit|credit limit|rate limit exceeded|payment required|402|billing|subscription (expired|inactive)|usage limit'

hit=$(echo "$resp" | grep -iEm1 "$pattern" || true)
[ -z "$hit" ] && exit 0

jq -n --arg ts "$(date +%s)" --arg ev "$(echo "$hit" | cut -c1-200)" \
  '{exhausted: true, ts: ($ts|tonumber), evidence: $ev}' > "$QUOTA_FILE" 2>/dev/null || true

msg="⚠ Quota Mixedbread (mgrep) marqué épuisé pour 24 h — motif détecté : $(echo "$hit" | cut -c1-120)

Le repli est maintenant autorisé sans passer par mgrep :
  • code  : mcp__token-savior__search_codebase / find_symbol  (gratuit)
  • web   : Context7 pour les docs de lib, WebSearch sinon

Réinitialiser après recharge : rm ~/.claude/state/mgrep_quota.json"

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $msg
  }
}'

exit 0
