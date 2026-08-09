#!/usr/bin/env bash
# PreToolUse hook — appends a JSONL entry per search-related tool call.
# Used by block-grep-search.sh to compute graduated friction.
# Always exits 0 (non-blocking, observability only).
#
# Tier mapping — RENUMÉROTÉ 2026-08-08. La hiérarchie n'est plus ordonnée par
# coût mais par COMPÉTENCE, mgrep prioritaire à compétence égale : l'abonnement
# Mixedbread est payé, il doit servir en premier sur ce qu'il fait le mieux
# (question sémantique en langage naturel), avec repli automatique vers le
# gratuit quand le quota est épuisé (cf. mgrep-quota-detect.sh).
#
#   1 = mgrep (Bash, commande commençant par 'mgrep') — sémantique payant,
#       PREMIER sur toute question en langage naturel
#   2 = index sémantique local gratuit, zéro file read — token-savior
#       (search_codebase, find_symbol, get_call_chain…), code-review-graph MCP
#       (project scope), context-mode ctx_search. Repli quota, et premier choix
#       quand le besoin est un symbole exact (mgrep gaspillerait un crédit).
#       Seuls les subtools de *localisation* comptent — une édition ou une
#       lecture ciblée de source n'est pas une recherche.
#   3 = ast-grep/sg — recherche structurelle AST, seule capable des motifs de
#       forme ; rewrite en place possible
#   4 = grep / rg / egrep / fgrep / find -name (Bash command, optionally
#       rtk-prefixed) or the native Grep tool — texte littéral, dernier recours
#   glob = Glob tool. Lists filenames, reads no content, and is not blocked by
#       block-grep-search.sh. Was counted as tier 4 until 2026-08-08, inflating
#       the very statistic used to justify hardening that hook.
#   web = WebSearch / WebFetch / Context7 / mgrep --web / tvly / firecrawl
#   sec = semgrep MCP (security scan — tracked for audit only, does NOT
#       satisfy the code-search gate in block-grep-search.sh)
#
# Tool-name prefixes are load-bearing: a wrong prefix fails silently, the entry
# is simply never written. Verify against the live tool list before editing one.
# Context7 was matched as mcp__plugin_context7_context7__* for months and logged
# zero entries — it is a user-scope MCP, so the real prefix is mcp__context7__*.
#
# Log format: ~/.claude/state/search_log.jsonl
#   {"ts":1714421000,"tier":1,"tool":"mcp__code-review-graph__semantic_search_nodes"}
#   {"ts":1714421120,"tier":4,"tool":"Bash","cmd":"grep -n foo bar.py"}

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
LOG_FILE="${STATE_DIR}/search_log.jsonl"
mkdir -p "$STATE_DIR"
touch "$LOG_FILE"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
ts=$(date +%s)

tier=""
extra=""

case "$tool_name" in
  mcp__code-review-graph__*)
    tier=2
    ;;
  # token-savior locating subtools. Listed explicitly rather than globbed: the
  # server also exposes editors (replace_symbol_source, add_field_to_model) and
  # targeted readers (get_function_source) that locate nothing.
  mcp__token-savior__search_codebase \
  | mcp__token-savior__ts_search \
  | mcp__token-savior__find_symbol \
  | mcp__token-savior__get_call_chain \
  | mcp__token-savior__get_entry_points \
  | mcp__token-savior__find_semantic_duplicates \
  | mcp__token-savior__find_dead_code)
    tier=2
    ;;
  mcp__plugin_context-mode_context-mode__ctx_search)
    tier=2
    ;;
  mcp__plugin_semgrep_guardian__*|mcp__semgrep__*)
    tier="sec"
    ;;
  Bash)
    cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
    if echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*mgrep([[:space:]]|$)'; then
      if echo "$cmd" | grep -qE '\-\-web'; then
        tier="web"
      else
        tier=1
      fi
    elif echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(tvly|firecrawl)([[:space:]]|$)'; then
      tier="web"
    elif echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*ast-grep([[:space:]]|$)'; then
      tier=3
    elif echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*sg[[:space:]].*(-p|--pattern|--rewrite|-l|--lang)([[:space:]=]|$)'; then
      tier=3
    elif echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(rtk[[:space:]]+)?(grep|rg|egrep|fgrep)([[:space:]]|$)'; then
      tier=4
    elif echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(rtk[[:space:]]+)?find[[:space:]].*-(name|iname|regex|path)'; then
      tier=4
    else
      exit 0  # non-search bash, skip
    fi
    extra=$(jq -n --arg c "$cmd" '{cmd: $c}')
    ;;
  Grep)
    tier=4
    pattern=$(echo "$input" | jq -r '.tool_input.pattern // ""')
    extra=$(jq -n --arg p "$pattern" '{pattern: $p}')
    ;;
  Glob)
    tier="glob"
    pattern=$(echo "$input" | jq -r '.tool_input.pattern // ""')
    extra=$(jq -n --arg p "$pattern" '{pattern: $p}')
    ;;
  WebSearch|WebFetch|mcp__context7__*|mcp__plugin_context7_context7__*)
    tier="web"
    ;;
  *)
    exit 0
    ;;
esac

# Build the tier value: numeric for 1/2/3/4, string for "web"/"sec"/"glob"
if [ "$tier" = "web" ] || [ "$tier" = "sec" ] || [ "$tier" = "glob" ]; then
  tier_json="\"$tier\""
else
  tier_json="$tier"
fi

# Compose JSONL line and append
if [ -n "$extra" ]; then
  jq -nc --arg ts "$ts" --argjson tier "$tier_json" --arg tool "$tool_name" --arg sid "$session_id" --argjson extra "$extra" \
    '{ts: ($ts|tonumber), tier: $tier, tool: $tool, session_id: $sid} + $extra' >> "$LOG_FILE"
else
  jq -nc --arg ts "$ts" --argjson tier "$tier_json" --arg tool "$tool_name" --arg sid "$session_id" \
    '{ts: ($ts|tonumber), tier: $tier, tool: $tool, session_id: $sid}' >> "$LOG_FILE"
fi

# Rotate if log gets large (> 5000 lines, keep last 2000)
lines=$(wc -l < "$LOG_FILE" | tr -d ' ')
if [ "$lines" -gt 5000 ]; then
  tail -n 2000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

exit 0
