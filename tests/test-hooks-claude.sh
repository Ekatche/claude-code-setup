#!/usr/bin/env bash
# Syntaxe des hooks + cohérence settings.json <-> fichiers présents.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

for f in claude/hooks/*.sh gemini/hooks/*.sh; do
  [ -e "$f" ] || continue
  bash -n "$f" || { echo "FAIL: bash -n $f"; fail=1; }
done

for f in claude/hooks/*.mjs; do
  [ -e "$f" ] || continue
  if command -v node >/dev/null 2>&1; then
    node --check "$f" || { echo "FAIL: node --check $f"; fail=1; }
  else
    echo "SKIP: node absent, $f non vérifié"
  fi
done

n=$(ls claude/hooks | wc -l | tr -d ' ')
[ "$n" -eq 13 ] || { echo "FAIL: $n hooks Claude, 13 attendus"; fail=1; }

# Chaque hook référencé par settings.json doit exister dans le repo.
python3 - <<'PY' || fail=1
import json, pathlib, re, sys
root = pathlib.Path(".")
s = (root / "claude/settings.json").read_text()
json.loads(s)
missing = []
for m in re.finditer(r'\$\{CLAUDE_CONFIG_DIR:-\$HOME/\.claude\}/hooks/([^"\\\s]+)', s):
    if not (root / "claude/hooks" / m.group(1)).exists():
        missing.append(m.group(1))
if missing:
    print("FAIL: hooks référencés mais absents:", missing)
    sys.exit(1)
print("PASS: settings.json <-> hooks cohérents")
PY

[ "$fail" -eq 0 ] && echo "PASS: test-hooks-claude"
exit "$fail"
