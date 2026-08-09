#!/usr/bin/env bash
# Refuse toute donnée privée avant qu'elle n'entre dans un dépôt public.
#
# Deux niveaux de motifs :
#   - génériques, commités ici — ils ne nomment rien de privé ;
#   - privés, dans scrub-patterns.local, gitignoré. Écrire un nom
#     d'utilisateur ou un nom de projet en dur ICI publierait exactement
#     la donnée que ce script existe pour retenir.
#
# Les motifs de clés sont ancrés sur une frontière de mot : sans ancrage,
# sk-[A-Za-z0-9_-]{16,} matche 'task-decomposition-expert'. Un contrôle qui
# crie au loup est désactivé ou lu en diagonale — pire que pas de contrôle,
# parce qu'il laisse croire qu'une vérification a eu lieu.
set -uo pipefail

BOUND='(^|[^A-Za-z0-9_-])'

# nom|regex ERE — une classe par ligne
PATTERNS="
home-absolu|/Users/[^/[:space:]\"]+/
home-absolu-linux|/home/[^/[:space:]\"]+/
cle-openai|${BOUND}sk-[A-Za-z0-9]{20,}
cle-github|${BOUND}gh[pousr]_[A-Za-z0-9]{30,}
cle-aws|${BOUND}AKIA[0-9A-Z]{16}
cle-firecrawl|${BOUND}fc-[0-9a-f]{24,}
cle-tavily|${BOUND}tvly-[A-Za-z0-9-]{16,}
cle-slack|${BOUND}xox[baprs]-[A-Za-z0-9-]{10,}
cle-privee-pem|BEGIN [A-Z ]*PRIVATE KEY
identite-oauth|oauthAccount
identite-user|\"userID\"
identite-machine|\"machineID\"
volume-externe|/Volumes/
"

LOCAL_FILE="$(dirname "$0")/scrub-patterns.local"

violations=0
scan_file() {
  local f="$1"
  while IFS='|' read -r name re; do
    [ -z "$name" ] && continue
    while IFS=: read -r lineno _; do
      [ -z "$lineno" ] && continue
      echo "$f:$lineno: $name"
      violations=$((violations + 1))
    done < <(grep -nE "$re" "$f" 2>/dev/null || true)
  done <<< "$PATTERNS"

  # Motifs privés : une ERE par ligne, # pour commenter.
  if [ -f "$LOCAL_FILE" ]; then
    while read -r re; do
      case "$re" in ''|'#'*) continue ;; esac
      while IFS=: read -r lineno _; do
        [ -z "$lineno" ] && continue
        echo "$f:$lineno: motif-prive-local"
        violations=$((violations + 1))
      done < <(grep -nE "$re" "$f" 2>/dev/null || true)
    done < "$LOCAL_FILE"
  fi
}

if [ "$#" -eq 0 ]; then
  echo "usage: scrub-check.sh <fichier|répertoire>..." >&2
  exit 2
fi

for target in "$@"; do
  if [ -d "$target" ]; then
    while IFS= read -r f; do scan_file "$f"; done < <(
      find "$target" -type f \
        -not -path '*/.git/*' \
        -not -name '*.png' -not -name '*.jpg' -not -name '*.svg'
    )
  elif [ -f "$target" ]; then
    scan_file "$target"
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "scrub-check: $violations violation(s) — écriture refusée." >&2
  exit 1
fi
exit 0
