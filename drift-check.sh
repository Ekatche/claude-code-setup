#!/usr/bin/env bash
# Lecture seule. Rapporte les écarts entre la machine et le manifeste.
# Ne corrige rien : corriger sans que l'utilisateur ait vu l'écart, c'est
# transformer une information en surprise.
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
drift=0

echo "== Plugins"
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  machine=$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$CLAUDE_DIR/settings.json" | sort)
  repo=$(jq -r '.plugins[]' "$REPO/manifest.json" | sort)
  d=$(comm -3 <(printf '%s\n' "$machine") <(printf '%s\n' "$repo"))
  if [ -n "$d" ]; then echo "$d" | sed 's/^\t/  seulement dans le repo: /; s/^\([^ ]\)/  seulement sur la machine: \1/'; drift=1
  else echo "  aligné"; fi
fi

echo "== CLI"
while IFS= read -r name; do
  command -v "$name" >/dev/null 2>&1 || { echo "  manquant: $name"; drift=1; }
done < <(jq -r '.cli[].name' "$REPO/manifest.json")

echo "== Fichiers non liés (nés hors repo)"
for d in hooks agents; do
  for f in "$CLAUDE_DIR/$d"/*; do
    [ -e "$f" ] || continue
    [ -L "$f" ] && continue
    case "$f" in *.bak.*|*.bak) continue ;; esac
    echo "  $f"; drift=1
  done
done

[ "$drift" -eq 0 ] && echo "Aucun écart."
exit 0
