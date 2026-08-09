#!/usr/bin/env bash
# Contrat d'E/S des hooks agy. Chaque hook est une fonction JSON -> JSON.
set -uo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
fail=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
mkdir -p "$TMP/.claude/state"

H="$REPO/gemini/hooks"

# 1. grep brut, aucun appel supérieur dans le tour -> deny + reason non vide
out=$(echo '{"tool_name":"run_shell_command","session_id":"s1","tool_input":{"command":"grep -rn foo ."}}' \
      | bash "$H/block-grep-search-gemini.sh")
d=$(printf '%s' "$out" | jq -r '.decision // ""')
r=$(printf '%s' "$out" | jq -r '.reason // ""')
[ "$d" = "deny" ] || { echo "FAIL: grep brut non bloqué (decision=$d)"; fail=1; }
[ -n "$r" ] || { echo "FAIL: deny sans reason"; fail=1; }

# 2. rtk grep passe toujours
out=$(echo '{"tool_name":"run_shell_command","session_id":"s1","tool_input":{"command":"rtk grep foo ."}}' \
      | bash "$H/block-grep-search-gemini.sh")
[ -z "$out" ] || { echo "FAIL: rtk grep bloqué: $out"; fail=1; }

# 3. BeforeAgent pose le marqueur de tour et renvoie du contexte
out=$(echo '{"prompt":"salut","session_id":"s2"}' | bash "$H/search-rule-reminder-gemini.sh")
c=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""')
[ -n "$c" ] || { echo "FAIL: BeforeAgent sans additionalContext"; fail=1; }
[ -f "$TMP/.claude/state/turn_start.s2.txt" ] || { echo "FAIL: marqueur de tour absent"; fail=1; }

# 4. mgrep journalisé en tier 1, puis grep autorisé dans le même tour
echo '{"tool_name":"run_shell_command","session_id":"s2","tool_input":{"command":"mgrep \"où est la config\""}}' \
  | bash "$H/track-search-gemini.sh"
tier=$(tail -n 1 "$TMP/.claude/state/search_log.jsonl" | jq -r '.tier')
[ "$tier" = "1" ] || { echo "FAIL: mgrep journalisé tier=$tier, 1 attendu"; fail=1; }

out=$(echo '{"tool_name":"run_shell_command","session_id":"s2","tool_input":{"command":"grep -rn foo ."}}' \
      | bash "$H/block-grep-search-gemini.sh")
[ -z "$out" ] || { echo "FAIL: grep bloqué malgré un mgrep dans le tour: $out"; fail=1; }

# 5. sg journalisé en tier 3
echo '{"tool_name":"run_shell_command","session_id":"s2","tool_input":{"command":"sg -p foo($$$A) -l python"}}' \
  | bash "$H/track-search-gemini.sh"
tier=$(tail -n 1 "$TMP/.claude/state/search_log.jsonl" | jq -r '.tier')
[ "$tier" = "3" ] || { echo "FAIL: sg journalisé tier=$tier, 3 attendu"; fail=1; }

# 6. Schéma de ligne identique à celui du harnais Claude
keys=$(tail -n 1 "$TMP/.claude/state/search_log.jsonl" | jq -r 'keys | sort | join(",")')
case "$keys" in
  *ts*) : ;;
  *) echo "FAIL: schéma de journal inattendu: $keys"; fail=1 ;;
esac
for k in ts tier tool session_id cmd; do
  tail -n 1 "$TMP/.claude/state/search_log.jsonl" | jq -e "has(\"$k\")" >/dev/null \
    || { echo "FAIL: clé $k absente du journal agy"; fail=1; }
done

# 7. Quota détecté depuis une sortie d'échec mgrep
echo '{"tool_name":"run_shell_command","tool_input":{"command":"mgrep foo"},"tool_response":{"llmContent":"error: out of credits"}}' \
  | bash "$H/mgrep-quota-detect-gemini.sh" >/dev/null
[ -f "$TMP/.claude/state/mgrep_quota.json" ] || { echo "FAIL: quota non marqué"; fail=1; }

[ "$fail" -eq 0 ] && echo "PASS: test-hooks-gemini"
exit "$fail"
