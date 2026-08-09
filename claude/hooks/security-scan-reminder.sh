#!/usr/bin/env bash
# PostToolUse hook on Edit|Write|MultiEdit — advisory nudge to run semgrep
# (mcp__plugin_semgrep_guardian__*) when a change touches security-sensitive
# surface (auth, secrets, injections, validation — matching the security
# baseline in ~/.claude/CLAUDE.md and project CLAUDE.md files) and no
# semgrep call has been logged (tier "sec" in search_log.jsonl) yet this
# turn/session. Non-blocking — advisory only, never denies the edit.
#
# Companion to block-grep-search.sh's search-hierarchy gate, but semgrep is
# deliberately NOT wired into that gate: it's a security scanner, not a code
# search substitute, so it must never let an agent skip the "check existing
# code first" requirement.

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
LOG_FILE="${STATE_DIR}/search_log.jsonl"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
content=$(echo "$input" | jq -r '
  if .tool_input.content then .tool_input.content
  elif .tool_input.new_string then .tool_input.new_string
  elif .tool_input.edits then (.tool_input.edits | map(.new_string // "") | join("\n"))
  else ""
  end
' 2>/dev/null || echo "")

haystack="${file_path}
${content}"

# Security-sensitive pattern set — mirrors the baseline in the global and
# project CLAUDE.md "Sécurité" sections (secrets, auth, injections, validation).
pattern='(auth|password|passwd|secret|token|api[_-]?key|login|session|permission|credential|sql|query\(|execute\(|exec\(|eval\(|subprocess|shell=True|crypto|encrypt|decrypt|hash|validate|sanitize|upload|jwt|oauth)'

if ! echo "$haystack" | grep -qEi "$pattern"; then
  exit 0
fi

# No log yet → nothing to check against, nudge unconditionally
if [ -f "$LOG_FILE" ]; then
  now=$(date +%s)
  hard_ceiling=$(( now - 600 ))

  turn_start_file="${STATE_DIR}/turn_start.${session_id}.txt"
  if [ -f "$turn_start_file" ]; then
    turn_start=$(cat "$turn_start_file" 2>/dev/null || echo "$hard_ceiling")
    [ "$turn_start" -gt "$hard_ceiling" ] 2>/dev/null && window="$turn_start" || window="$hard_ceiling"
  else
    window="$hard_ceiling"
  fi

  sec_recent=$(tail -n 200 "$LOG_FILE" 2>/dev/null | jq -r --argjson since "$window" --arg sid "$session_id" \
    'select(.ts >= $since and .tier == "sec" and .session_id == $sid) | .ts' 2>/dev/null | wc -l | tr -d ' ')

  if [ "$sec_recent" -gt 0 ] 2>/dev/null; then
    exit 0
  fi
fi

msg="🔒 $tool_name touche une surface sensible sécurité (auth/secret/injection/validation) sans scan semgrep ce tour — avant de considérer le changement terminé, lance mcp__plugin_semgrep_guardian__get_semgrep_sast_findings (ou get_semgrep_secrets_findings pour les secrets) sur ce fichier. Rappel non-bloquant, pas une obligation immédiate."

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $msg
  }
}'

exit 0
