#!/usr/bin/env bash
# PostToolUse hook on Bash|mcp__.* — détecte un outil/MCP mal configuré (clé API
# absente, projet non enregistré, serveur inaccessible) et empêche l'échec
# silencieux : injecte une consigne pour que Claude explique le problème à
# l'utilisateur et propose de l'aider à le configurer, au lieu de continuer
# comme si de rien n'était ou d'abandonner sans un mot.
#
# Différent de mgrep-quota-detect.sh : un quota se recharge tout seul (repli
# automatique légitime). Une config absente ne se corrige pas toute seule —
# ce hook ne doit donc jamais "autoriser un repli silencieux", seulement
# forcer la conversation avec l'utilisateur.
#
# État écrit : ~/.claude/state/tool_config_alerts.json
#   {"<clé>": <epoch dernier signalement>}
# Sert uniquement d'anti-spam (throttle), pas de cache de statut : le fichier
# ne dit jamais "c'est réparé", il dit juste "on l'a déjà signalé récemment".
#
# Réinitialisation manuelle : rm ~/.claude/state/tool_config_alerts.json

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
ALERT_FILE="${STATE_DIR}/tool_config_alerts.json"
mkdir -p "$STATE_DIR"

THROTTLE=600  # 10 min — anti-spam seulement, pas une fenêtre de silence légitime

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

resp=$(echo "$input" | jq -r '
  .tool_response as $r
  | if ($r|type) == "string" then $r
    elif ($r|type) == "object" then
      ( [ ($r.output? // empty), ($r.stdout? // empty), ($r.stderr? // empty),
          ($r.error? // empty), ($r.message? // empty),
          ($r.content? // [] | map(.text? // empty) | join("\n")) ]
        | map(select(. != null and . != "")) | join("\n") )
    else ($r | tostring)
    end
' 2>/dev/null || echo "")

[ -z "$resp" ] && exit 0

key=""
msg=""

# 1. token-savior : aucun projet enregistré (WORKSPACE_ROOTS manquant)
if [ -z "$key" ] && echo "$tool_name" | grep -q '^mcp__token-savior__' \
   && echo "$resp" | grep -qiE 'no projects registered'; then
  key="token-savior"
  msg="⚠ token-savior : aucun projet enregistré pour ce serveur MCP — set_project_root n'est pas annoncé par le profil 'optimized' (15/69 tools), impossible de s'auto-corriger par un simple appel d'outil.

Fix : ajouter WORKSPACE_ROOTS (chemins absolus, séparés par des virgules) à l'env du serveur token-savior dans ~/.claude.json — bloc exact dans PREREQUISITES.md § 'Environnement Python token-savior'.

Ne pas échouer silencieusement ni continuer sans cet outil sans le dire : demande à l'utilisateur (AskUserQuestion) s'il veut que tu l'aides à l'ajouter maintenant, puis édite ~/.claude.json avec sa permission."
fi

# 2. mgrep : pas de session Mixedbread valide (distinct du quota, déjà géré ailleurs)
if [ -z "$key" ] && echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*mgrep([[:space:]]|$)' \
   && echo "$resp" | grep -qiE 'not (logged in|authenticated)|no active session|please (run )?mgrep login|unauthorized|401|invalid api key|authentication required'; then
  key="mgrep-auth"
  msg="⚠ mgrep : pas de session Mixedbread valide (pas un problème de quota — mgrep-quota-detect.sh gère ce cas séparément).

Fix : 'mgrep login' est un flux OAuth interactif — l'utilisateur doit le lancer lui-même dans son propre terminal, ce n'est pas un appel que tu dois faire à sa place.

Ne pas échouer silencieusement : préviens l'utilisateur, propose d'attendre qu'il se connecte, puis reprends la recherche avec mgrep."
fi

# 3. tvly / firecrawl (CLI) : clé API absente ou invalide
if [ -z "$key" ] && echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(tvly|firecrawl)([[:space:]]|$)' \
   && echo "$resp" | grep -qiE 'api key|unauthorized|401|invalid.*key|missing.*key'; then
  tool_cli=$(echo "$cmd" | grep -oE '(tvly|firecrawl)' | head -1)
  key="cli-${tool_cli}"
  msg="⚠ ${tool_cli} : clé API absente ou invalide.

Fix : clé personnelle à renseigner dans ~/.gemini/config/mcp_config.json — voir PREREQUISITES.md § 'Remplir mcp_config.json' (placeholders <TAVILY_API_KEY> / <FIRECRAWL_API_KEY>).

Ne pas échouer silencieusement : demande à l'utilisateur s'il a déjà un compte ${tool_cli} et une clé, propose de l'aider à ouvrir/éditer le fichier de config."
fi

# 4. Serveur MCP générique down ou mal configuré
if [ -z "$key" ] && echo "$tool_name" | grep -qE '^mcp__' \
   && echo "$resp" | grep -qiE 'ENOENT|command not found|MCP error|server disconnected|connection closed|environment variable .* not set|missing required env'; then
  server=$(echo "$tool_name" | sed -E 's/^mcp__([a-zA-Z0-9_-]+)__.*/\1/')
  key="mcp-${server}"
  msg="⚠ Serveur MCP '${server}' semble mal configuré ou indisponible (erreur détectée dans la réponse de l'outil).

Ne pas échouer silencieusement : explique l'erreur à l'utilisateur en clair, vérifie avec lui la config de ce serveur (~/.claude.json ou ~/.gemini/config/mcp_config.json selon le harnais), et propose ton aide pour la corriger avant de retenter l'appel."
fi

[ -z "$key" ] && exit 0

# Throttle anti-spam : un même échec ne redéclenche pas l'injection plus d'une
# fois toutes les THROTTLE secondes (le problème reste réel entre-temps, seul
# le rappel se tait).
now=$(date +%s)
last=$(jq -r --arg k "$key" '.[$k] // 0' "$ALERT_FILE" 2>/dev/null || echo 0)
if [ "$((now - last))" -lt "$THROTTLE" ]; then
  exit 0
fi

tmp=$(mktemp)
jq --arg k "$key" --argjson ts "$now" '.[$k] = $ts' "$ALERT_FILE" 2>/dev/null > "$tmp" \
  || jq -n --arg k "$key" --argjson ts "$now" '{($k): $ts}' > "$tmp"
mv "$tmp" "$ALERT_FILE"

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $msg
  }
}'

exit 0
