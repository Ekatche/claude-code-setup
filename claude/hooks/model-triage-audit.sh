#!/usr/bin/env bash
# PreToolUse hook on Agent|Workflow — logs model/effort choice for audit, non-blocking.
#
# Doesn't guess the "right" model for the task (unreliable classification) — just
# records what was dispatched so the user can audit a posteriori whether CLAUDE.md's
# "Calibration par modèle" table is actually being followed. See CLAUDE.md global
# section "Calibration par modèle (Claude)".

set -euo pipefail

STATE_DIR="${HOME}/.claude/state"
LOG_FILE="${STATE_DIR}/model_triage_audit.jsonl"
mkdir -p "$STATE_DIR"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

[ "$tool_name" != "Agent" ] && [ "$tool_name" != "Workflow" ] && exit 0

model=$(echo "$input" | jq -r '.tool_input.model // "inherited"')
effort=$(echo "$input" | jq -r '.tool_input.effort // .tool_input.opts.effort // "inherited"')
subagent_type=$(echo "$input" | jq -r '.tool_input.subagent_type // .tool_input.agentType // "default"')
desc=$(echo "$input" | jq -r '(.tool_input.description // .tool_input.prompt // .tool_input.script // "") | .[0:200]')

jq -nc \
  --arg ts "$(date +%s)" \
  --arg session_id "$session_id" \
  --arg tool "$tool_name" \
  --arg model "$model" \
  --arg effort "$effort" \
  --arg subagent_type "$subagent_type" \
  --arg desc "$desc" \
  '{ts: ($ts|tonumber), session_id: $session_id, tool: $tool, model: $model, effort: $effort, subagent_type: $subagent_type, desc: $desc}' \
  >> "$LOG_FILE" 2>/dev/null || true

# Rotate if log gets large (> 5000 lines, keep last 2000)
lines=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ')
if [ -n "$lines" ] && [ "$lines" -gt 5000 ] 2>/dev/null; then
  tail -n 2000 "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null || true
fi

exit 0
