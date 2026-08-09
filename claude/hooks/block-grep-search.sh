#!/usr/bin/env bash
# PreToolUse hook on Bash|Grep — zero-grace HARD BLOCK for grep/rg/find and the native
# Grep tool whenever no code-review-graph/mgrep activity happened in the last 10 min.
# Reads the search log written by track-search.sh to check that recent activity.
#
# Mutated 2026-05-04 from "warn-only" to "warn-then-deny", then 2026-07-09 to zero-grace
# deny: data showed 70% grep / 0.4% mgrep despite warnings, and user pays for mgrep —
# a warned-but-allowed grep still wastes the tokens the subscription exists to avoid.
# Backups: block-grep-search.sh.warn-only.bak.20260504, .warn-then-deny.bak.20260709
#
# Extended 2026-07-09 to also cover the native Grep tool — the Bash-only version missed
# every Grep tool-call loop since those never go through Bash.
#
# Whitelist (always allow):
#   - data-file / non-codebase exception (scrapes, temp, JSON/CSV/log — not indexed by graph/mgrep)
#   - any tier-1, tier-2 or tier-3 call in THIS session AND THIS turn
#
# 2026-08-08: tier 1 used to mean code-review-graph alone, which is a
# project-scope MCP. Outside those projects the only reachable exits were mgrep
# (paid) and ast-grep — so the hook pushed work onto a paid tool while the free
# local index sat unused. track-search.sh now also counts token-savior and
# context-mode search subtools as tier 1. See its header for the tier table.
#
# Removed 2026-08-03: the `# justified: <reason>` free-form bypass marker. It let any grep
# skip the search-hierarchy gate on self-declared justification with zero verification —
# an escape hatch from the discipline the hook exists to enforce, not a real exemption.
# The data-file exception below stays: it's scoped to files genuinely outside the
# codebase (mgrep/graph don't index them), not a discipline bypass.
#
# Note: pipe-grep (`cat foo | grep bar`) is already excluded by the regex (only matches
# grep at command boundary: ^, &&, ;, ||).
#
# Hardened 2026-07-10: the freshness window used to be a flat "last 10 min" over the
# global log, shared across every session and surviving /clear. One legitimate mgrep
# call anywhere opened a 10-min grace period during which totally unrelated tasks
# (including a fresh /clear'd conversation) could grep freely — confirmed in session
# 588b4fff (7 unblocked greps after a stale mgrep call from 2.4 min earlier, prior
# task). Fix: scope the check to (a) this session_id only, (b) since this turn's
# start (written by search-rule-reminder.sh on UserPromptSubmit), not a fixed clock
# window. A prior turn's or prior session's tier1/tier3 call no longer counts.

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
LOG_FILE="${STATE_DIR}/search_log.jsonl"
BYPASS_LOG="${STATE_DIR}/search_bypass.jsonl"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

# Detect search-style commands (only grep/find for code search; pipe-grep excluded)
is_search=0
is_native_grep=0
if [ "$tool_name" = "Grep" ]; then
  is_search=1
  is_native_grep=1
fi
if echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*(rtk[[:space:]]+)?(grep|rg|egrep|fgrep)([[:space:]]|$)'; then
  is_search=1
fi
if echo "$cmd" | grep -qE '(^|&&|;|\|\|)[[:space:]]*find[[:space:]].*-(name|iname|regex|path)'; then
  is_search=1
fi

[ "$is_search" = "0" ] && exit 0

# Data-file / non-codebase exception (Bash grep only): rtk grep est l'outil correct pour
# l'extraction littérale de fichiers que mgrep/graph n'indexent pas (scrapes, temp,
# JSON/CSV/log) — passe par rtk comme cat/ls/git pour garder la compaction token.
# Autorise silencieusement (loggé pour audit).
if [ "$is_native_grep" = "0" ] && echo "$cmd" | grep -qE '(/tmp/|/private/tmp/|/scratchpad/|\.firecrawl/|\.(json|jsonl|ndjson|log|csv|tsv)([[:space:]"'\'']|$))'; then
  jq -nc --arg ts "$(date +%s)" --arg cmd "$cmd" \
    '{ts: ($ts|tonumber), event: "data_exempt", cmd: $cmd}' \
    >> "$BYPASS_LOG" 2>/dev/null || true
  exit 0
fi

# No log yet → silent first run, allow
if [ ! -f "$LOG_FILE" ]; then
  exit 0
fi

now=$(date +%s)
hard_ceiling=$(( now - 600 ))  # 10 min absolute ceiling, never look back further than this

# Turn boundary for this session: written by search-rule-reminder.sh on each
# UserPromptSubmit. Missing file (older session, hook not yet fired) → fall back
# to the 10-min ceiling only, don't newly restrict what already worked.
turn_start_file="${STATE_DIR}/turn_start.${session_id}.txt"
if [ -f "$turn_start_file" ]; then
  turn_start=$(cat "$turn_start_file" 2>/dev/null || echo "$hard_ceiling")
  [ "$turn_start" -gt "$hard_ceiling" ] 2>/dev/null && graph_window="$turn_start" || graph_window="$hard_ceiling"
else
  graph_window="$hard_ceiling"
fi

recent_log=$(tail -n 200 "$LOG_FILE" 2>/dev/null || true)
[ -z "$recent_log" ] && exit 0

# Count tier-1 entries (code-review-graph) since this turn started, THIS session only
tier1_recent=$(echo "$recent_log" | jq -r --argjson since "$graph_window" --arg sid "$session_id" \
  'select(.ts >= $since and .tier == 1 and .session_id == $sid) | .ts' 2>/dev/null | wc -l | tr -d ' ')

# Count tier-3 entries (mgrep local) since this turn started, THIS session only — also
# counts as legitimate intermediate
tier3_recent=$(echo "$recent_log" | jq -r --argjson since "$graph_window" --arg sid "$session_id" \
  'select(.ts >= $since and .tier == 3 and .session_id == $sid) | .ts' 2>/dev/null | wc -l | tr -d ' ')

# Count tier-2 entries (ast-grep structural search) since this turn started, THIS
# session only — also counts as legitimate intermediate
tier2_recent=$(echo "$recent_log" | jq -r --argjson since "$graph_window" --arg sid "$session_id" \
  'select(.ts >= $since and .tier == 2 and .session_id == $sid) | .ts' 2>/dev/null | wc -l | tr -d ' ')

# Recent graph, ast-grep, or mgrep activity → silent allow (legitimate fallback to grep)
if [ "$tier1_recent" -gt 0 ] || [ "$tier2_recent" -gt 0 ] || [ "$tier3_recent" -gt 0 ]; then
  exit 0
fi

# No higher-tier activity. Zero grace: deny from the 1st grep/Grep-tool call.
msg="🚫 BLOQUÉ — grep/find/Grep-tool sans aucune recherche de tier supérieur depuis le début de ce tour (cette session).

Choisis selon le BESOIN, pas selon le prix. L'abonnement mgrep est payé : il
passe en premier sur ce qu'il fait le mieux.

QUESTION SÉMANTIQUE, en langage naturel (« où gère-t-on l'expiration des
tokens ? ») :
  • Bash : mgrep '<question>'            ← PREMIER CHOIX (crédits Mixedbread)
  • repli si quota épuisé, ou si tu veux rester gratuit :
      mcp__token-savior__search_codebase

SYMBOLE PRÉCIS dont tu connais déjà le nom — n'y gaspille pas un crédit :
  • mcp__token-savior__find_symbol       (fichier, ligne, signature)
  • mcp__token-savior__get_call_chain    (appelants / appelés)

MOTIF STRUCTUREL (une forme de code, pas du texte) — seul ast-grep sait faire :
  • Bash : ast-grep -p '<motif>' -l <lang>
  • Bash : ast-grep outline -l <lang> <file>   (structure d'un fichier, zéro Read)

SI LE PROJET A UN GRAPHE (MCP project-scope, absent hors de ces projets) :
  • mcp__code-review-graph__semantic_search_nodes_tool
  • mcp__code-review-graph__query_graph_tool
  • mcp__code-review-graph__get_impact_radius_tool

TEXTE LITTÉRAL EXACT (chaîne d'erreur, clé de config), une fois l'un des
précédents appelé :
  • Bash : rtk grep '<texte>' <path>     (PAS grep brut — rtk compacte comme
                                           pour cat/git/ls)

Pas de bypass par commentaire : fais un appel de tier supérieur légitime d'abord."

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $msg
  }
}'
exit 0
