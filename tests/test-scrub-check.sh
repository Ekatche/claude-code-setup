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

# 3. Absence de scrub-patterns.local (le cas de la CI) : le script ne doit pas
#    casser, MAIS il doit avertir sur stderr. Un vert silencieux sur un contrôle
#    à moitié désactivé a déjà laissé passer un nom de projet privé dans quatre
#    fichiers — l'avertissement est la correction, donc il est testé.
#    Le test s'isole dans un répertoire temporaire : ici, le .local existe.
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT
cp scrub-check.sh "$TMPD/"
printf 'rien de sensible\n' > "$TMPD/clean.txt"
err=$("$TMPD/scrub-check.sh" "$TMPD/clean.txt" 2>&1 >/dev/null); rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: scrub-check casse sans scrub-patterns.local (rc=$rc)"; fail=1
fi
case "$err" in
  *AVERTISSEMENT*) : ;;
  *) echo "FAIL: aucun avertissement quand scrub-patterns.local est absent"; fail=1 ;;
esac

# 4. Présent, il doit effectivement bloquer un motif privé — sinon le fichier
#    n'est qu'un placebo.
printf 'NomDeProjetSecret\n' > "$TMPD/scrub-patterns.local"
printf 'chemin vers NomDeProjetSecret/src\n' > "$TMPD/leak.txt"
if "$TMPD/scrub-check.sh" "$TMPD/leak.txt" >/dev/null 2>&1; then
  echo "FAIL: motif privé non détecté malgré scrub-patterns.local"; fail=1
fi

# 5. Le script s'exclut lui-même (il porte ses motifs en clair), mais
#    l'exclusion doit tenir au CHEMIN, pas au NOM : un autre fichier baptisé
#    scrub-check.sh ne devient pas une zone franche.
if ! ./scrub-check.sh scrub-check.sh >/dev/null 2>&1; then
  echo "FAIL: scrub-check se refuse lui-même"; fail=1
fi
mkdir -p "$TMPD/ailleurs"
cp scrub-check.sh "$TMPD/ailleurs/scrub-check.sh"
if ./scrub-check.sh "$TMPD/ailleurs/scrub-check.sh" >/dev/null 2>&1; then
  echo "FAIL: exclusion par nom de fichier — un homonyme échappe au scan"; fail=1
fi

[ "$fail" -eq 0 ] && echo "PASS: test-scrub-check"
exit "$fail"
