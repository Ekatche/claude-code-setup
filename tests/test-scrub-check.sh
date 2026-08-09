#!/usr/bin/env bash
# Test de scrub-check.sh. Un contrôle de sécurité jamais vu rouge ne prouve rien.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

# 1. Le fixture sale doit échouer, et signaler chacune des 11 lignes.
out=$(./scrub-check.sh tests/fixtures/leaky.txt); rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: leaky.txt accepté (rc=0)"; fail=1
else
  n=$(printf '%s\n' "$out" | grep -c ':' || true)
  if [ "$n" -lt 11 ]; then
    echo "FAIL: seulement $n violations détectées sur 11"
    printf '%s\n' "$out"; fail=1
  fi
fi

# 2. Le fixture propre doit passer. Régression du faux positif
#    sk-[A-Za-z0-9_-]{16,} contre 'task-decomposition-expert'.
if ! ./scrub-check.sh tests/fixtures/clean.txt >/dev/null; then
  echo "FAIL: clean.txt refusé — faux positif"
  ./scrub-check.sh tests/fixtures/clean.txt; fail=1
fi

# 3. Les motifs privés viennent du .local, absent en CI : son absence
#    ne doit pas faire échouer le script.
if ! ./scrub-check.sh tests/fixtures/clean.txt >/dev/null 2>&1; then
  echo "FAIL: scrub-check casse sans scrub-patterns.local"; fail=1
fi

[ "$fail" -eq 0 ] && echo "PASS: test-scrub-check"
exit "$fail"
