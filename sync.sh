#!/usr/bin/env bash
# machine -> repo. Avec des symlinks, la dérive n'existe pas pour les fichiers
# liés : éditer ~/.claude/hooks/x.sh édite le fichier du repo. Ce script ne
# couvre donc que ce que le symlink ne couvre pas.
#
# ORDRE CRITIQUE : scrubber transforme, scrub-check valide, l'écriture n'a lieu
# qu'après. Écrire puis vérifier, c'est publier le secret puis le découvrir.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
GEMINI_DIR="${GEMINI_DIR:-$HOME/.gemini}"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

scrub() {  # scrub <src> <dst-dans-WORK>
  python3 - "$1" "$WORK/$2" <<'PY'
import json, os, pathlib, sys
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
text = src.read_text()
home = str(pathlib.Path.home())
text = text.replace(home + "/.claude", "${CLAUDE_CONFIG_DIR:-$HOME/.claude}")
text = text.replace(home + "/.gemini", "${GEMINI_DIR:-$HOME/.gemini}")
text = text.replace(home, "$HOME")
json.loads(text)
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text(text)
PY
}

echo "== 1. settings.json (les deux harnais)"
scrub "$CLAUDE_DIR/settings.json" "claude-settings.json"
[ -f "$GEMINI_DIR/settings.json" ] && scrub "$GEMINI_DIR/settings.json" "gemini-settings.json"
[ -f "$GEMINI_DIR/config/config.json" ] && scrub "$GEMINI_DIR/config/config.json" "gemini-config.json"

echo "== 2. manifeste"
if command -v claude >/dev/null 2>&1; then
  python3 - "$REPO/manifest.json" "$CLAUDE_DIR/settings.json" "$WORK/manifest.json" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1]))
settings = json.load(open(sys.argv[2]))
manifest["plugins"] = sorted(k for k, v in settings.get("enabledPlugins", {}).items() if v)
json.dump(manifest, open(sys.argv[3], "w"), indent=2, ensure_ascii=False)
open(sys.argv[3], "a").write("\n")
PY
else
  cp "$REPO/manifest.json" "$WORK/manifest.json"
fi

echo "== 3. modèle mcp_config — noms de serveurs seulement, jamais de valeur"
if [ -f "$GEMINI_DIR/config/mcp_config.json" ]; then
  python3 - "$GEMINI_DIR/config/mcp_config.json" "$WORK/mcp_config.json.example" <<'PY'
import json, re, sys
cfg = json.load(open(sys.argv[1]))
for name, srv in cfg.get("mcpServers", {}).items():
    for k in list(srv.get("env", {})):
        srv["env"][k] = f"<{k}>"
    srv["args"] = [re.sub(r"(?i)(apikey=)[^&\"]+", r"\1<API_KEY>", a) for a in srv.get("args", [])]
json.dump(cfg, open(sys.argv[2], "w"), indent=2)
open(sys.argv[2], "a").write("\n")
PY
fi

echo "== 4. fichiers nés hors repo"
for d in hooks agents; do
  for f in "$CLAUDE_DIR/$d"/*; do
    [ -e "$f" ] || continue
    [ -L "$f" ] && continue
    case "$f" in *.bak.*|*.bak) continue ;; esac
    echo "  non lié, à adopter: $f"
  done
done

echo "== 5. scrub-check AVANT écriture"
if ! "$REPO/scrub-check.sh" "$WORK"; then
  echo "sync interrompu : rien n'a été écrit dans le repo." >&2
  exit 1
fi

echo "== 6. écriture"
cp "$WORK/claude-settings.json" "$REPO/claude/settings.json"
[ -f "$WORK/gemini-settings.json" ] && cp "$WORK/gemini-settings.json" "$REPO/gemini/settings.json"
[ -f "$WORK/gemini-config.json" ] && cp "$WORK/gemini-config.json" "$REPO/gemini/config/config.json"
[ -f "$WORK/mcp_config.json.example" ] && cp "$WORK/mcp_config.json.example" "$REPO/gemini/config/mcp_config.json.example"
cp "$WORK/manifest.json" "$REPO/manifest.json"
echo "Terminé."
