#!/usr/bin/env bash
# PreToolUse hook on Edit / Write / MultiEdit — surfaces the Documentation-
# First rule from CLAUDE.md when editing source code.
#
# When the file path matches a known feature folder, injects a reminder
# pointing at the relevant docs (per the table in the project's CLAUDE.md).
# Project-specific mappings live in this script — keep them in sync with
# the project CLAUDE.md table.
#
# NEVER blocks (exit 0 always). Pure visibility.

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

[ -z "$file_path" ] && exit 0

# Only trigger for known FileNamer source paths
case "$file_path" in
  */backend/services/chat/*|*/backend/api/routes/chat/*)
    doc="docs/features/backend/analysis/chat/" ;;
  */backend/services/rag/*|*/backend/services/embeddings*)
    doc="docs/features/backend/analysis/rag/" ;;
  */backend/services/contre_argumentaire*|*/backend/api/routes/contre_argumentaire*)
    doc="docs/features/backend/contre-argumentaire.md" ;;
  */backend/services/document/naming*|*/backend/services/llm/mistral/pdf_pipeline*)
    doc="docs/features/backend/document/naming-pipeline.md" ;;
  */backend/services/pdf_tools/*|*/backend/api/routes/pdf_tools/*)
    doc="docs/features/backend/pdf-tools/ — vérifie aussi fraud-detection.md, smart-fixer.md selon le sous-outil" ;;
  */backend/services/piece_referencing*)
    doc="docs/features/backend/piece-referencing.md" ;;
  */webapp/src/pages/private/cases/*|*/webapp/src/components/cases/*)
    doc="docs/features/frontend/pages/cases/" ;;
  */webapp/src/pages/private/Chat*|*/webapp/src/components/chat/*)
    doc="docs/features/frontend/pages/chat.md" ;;
  */backend/workers/*|*/backend/services/llm/mistral*)
    doc="memory/taskiq_startup_recovery.md, memory/mistral_models_mapping.md" ;;
  */backend/migrations/*|*/backend/models/database/*|*/backend/core/auth*)
    doc="docs/architecture/backend.md (DB migrations / Auth)" ;;
  *)
    exit 0 ;;
esac

msg="📚 Doc-First (CLAUDE.md): avant d'éditer ${file_path##*/}, lis ${doc}. Si tu n'as pas consulté la doc dans cette session, fais-le maintenant."

jq -n --arg msg "$msg" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: $msg
  }
}'
exit 0
