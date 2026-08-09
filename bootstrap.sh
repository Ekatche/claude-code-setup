#!/usr/bin/env bash
# repo -> machine. Symlinks partout, sauf les settings.json (vrais fichiers
# copiés : ils portent des valeurs de machine et doivent rester modifiables
# localement sans réécrire le repo).
#
# Idempotent : relancer ne casse rien. Ne supprime jamais un fichier existant
# sans le sauvegarder d'abord.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
GEMINI_DIR="${GEMINI_DIR:-$HOME/.gemini}"
STAMP=$(date +%Y%m%d%H%M%S)

say() { printf '  %s\n' "$*"; }

backup_then_link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then rm "$dst"
  elif [ -e "$dst" ]; then mv "$dst" "${dst}.bak.${STAMP}"; say "sauvegardé: ${dst}.bak.${STAMP}"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
}

copy_if_absent() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then say "conservé (existe déjà): $dst"; return; fi
  mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"
}

echo "== Claude Code -> $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/memory"
for f in CLAUDE.md RTK.md CONTEXT.md; do
  backup_then_link "$REPO/claude/$f" "$CLAUDE_DIR/$f"
done
for f in "$REPO"/claude/hooks/*; do
  backup_then_link "$f" "$CLAUDE_DIR/hooks/$(basename "$f")"
done
for f in "$REPO"/claude/agents/*.md; do
  backup_then_link "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
done
backup_then_link "$REPO/claude/skill-sources" "$CLAUDE_DIR/skill-sources"
copy_if_absent "$REPO/claude/settings.json" "$CLAUDE_DIR/settings.json"
copy_if_absent "$REPO/claude/MEMORY.md" "$CLAUDE_DIR/MEMORY.md"

echo "== Antigravity (agy) -> $GEMINI_DIR"
mkdir -p "$GEMINI_DIR/hooks" "$GEMINI_DIR/config/skills"
for f in GEMINI.md AGENTS.md; do
  backup_then_link "$REPO/gemini/$f" "$GEMINI_DIR/$f"
done
for f in "$REPO"/gemini/hooks/*.sh; do
  backup_then_link "$f" "$GEMINI_DIR/hooks/$(basename "$f")"
done
for d in "$REPO"/gemini/config/skills/*/; do
  backup_then_link "${d%/}" "$GEMINI_DIR/config/skills/$(basename "${d%/}")"
done
# Les deux skills partagées : une seule source, deux harnais.
for s in micro-dev executing-micro-plans; do
  backup_then_link "$REPO/claude/skill-sources/$s" "$GEMINI_DIR/config/skills/$s"
done
copy_if_absent "$REPO/gemini/settings.json" "$GEMINI_DIR/settings.json"
copy_if_absent "$REPO/gemini/config/config.json" "$GEMINI_DIR/config/config.json"

if [ ! -e "$GEMINI_DIR/config/mcp_config.json" ]; then
  cp "$REPO/gemini/config/mcp_config.json.example" "$GEMINI_DIR/config/mcp_config.json"
  say "mcp_config.json créé depuis le modèle — REMPLACER les placeholders par vos clés"
fi

echo "== Dépendances"
missing=0
while IFS= read -r name; do
  command -v "$name" >/dev/null 2>&1 || { say "MANQUANT: $name"; missing=1; }
done < <(jq -r '.cli[].name' "$REPO/manifest.json")
[ "$missing" -eq 0 ] && say "toutes les CLI sont présentes"

echo "== Plugins (nécessite la CLI claude)"
if command -v claude >/dev/null 2>&1; then
  jq -r '.marketplaces[] | .repo' "$REPO/manifest.json" | while read -r repo; do
    claude plugin marketplace add "$repo" || say "déjà ajouté: $repo"
  done
  jq -r '.plugins[]' "$REPO/manifest.json" | while read -r p; do
    claude plugin install "$p" || say "échec: $p"
  done
else
  say "CLI claude absente — installer les plugins manuellement, cf. README"
fi

if command -v agy >/dev/null 2>&1; then
  agy plugin import claude || say "agy plugin import claude a échoué"
else
  say "CLI agy absente — étape Antigravity ignorée"
fi

echo
echo "Terminé. Lire PREREQUISITES.md : les clés API ne sont pas fournies."
