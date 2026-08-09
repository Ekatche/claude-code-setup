#!/usr/bin/env bash
# PreToolUse hook on Edit / Write / MultiEdit — surfaces the "read the docs
# first" rule when editing source code.
#
# The mechanism is generic: match the file being edited against a path
# pattern, and inject a reminder pointing at the doc that covers it.
#
# The MAPPING is project-specific and intentionally empty here. This file
# ships in a public repository: a real mapping table describes the internal
# architecture of whatever codebase it was written for — module names,
# feature boundaries, service layout. That is a disclosure, not a config.
#
# To use it: copy the example block below, replace the patterns with your own
# feature folders, and keep it in sync with your project's CLAUDE.md table.
#
# NEVER blocks (exit 0 always). Pure visibility.

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

[ -z "$file_path" ] && exit 0

# --- Mapping, à remplir par projet -----------------------------------------
# Exemple, à adapter puis décommenter :
#
# case "$file_path" in
#   */backend/services/auth/*|*/backend/api/routes/auth/*)
#     doc="docs/features/backend/auth/" ;;
#   */webapp/src/pages/checkout/*)
#     doc="docs/features/frontend/checkout.md" ;;
#   *)
#     exit 0 ;;
# esac
#
# Tant que le bloc ci-dessus est commenté, le hook ne fait rien : c'est le
# comportement voulu sur une machine neuve, pas une panne.
exit 0
# ---------------------------------------------------------------------------

# shellcheck disable=SC2317  # atteint une fois le mapping ci-dessus activé
msg="📚 Doc-First (CLAUDE.md): avant d'éditer ${file_path##*/}, lis ${doc}. Si tu n'as pas consulté la doc dans cette session, fais-le maintenant."

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  }
}'
exit 0
