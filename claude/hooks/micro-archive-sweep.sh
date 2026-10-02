#!/usr/bin/env bash
# SessionStart hook, matcher "startup|resume" — balayage d'archive de micro-dev.
#
# Déplace hors de la racine de docs/micro ce qui est terminé :
#   - un dossier <YYYYMMDD>-<slug>/ dont PLAN.md porte `status: done`
#     -> archive/<YYYY-MM>/, et son lien dans INDEX.md est réécrit ;
#   - un DAILY_LOG d'un mois antérieur au mois courant -> archive/<YYYY-MM>/.
#
# Pourquoi un hook et pas l'agent : le même balayage fait par l'agent était
# refusé par le classifieur de permissions (boucle de mv + sed) et coûtait
# plusieurs minutes par invocation de micro-dev. Ici c'est déterministe,
# gratuit, et fait une fois par session.
#
# Ne commite jamais : les déplacements restent des renommages non commités.
# Silencieux quand rien ne bouge. Voir la skill micro-dev, § Archive Sweep.

set -uo pipefail

input=$(cat 2>/dev/null || true)
cwd=""
if command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
[ -n "$cwd" ] || cwd=$PWD

micro="$cwd/docs/micro"
[ -d "$micro" ] || exit 0

# Jamais pendant un merge ou un rebase en cours : déplacer des fichiers au
# milieu d'une résolution de conflits brouillerait l'état que l'utilisateur gère.
if gitdir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null); then
  case "$gitdir" in /*) ;; *) gitdir="$cwd/$gitdir" ;; esac
  for f in MERGE_HEAD rebase-merge rebase-apply CHERRY_PICK_HEAD; do
    [ -e "$gitdir/$f" ] && exit 0
  done
fi

cd "$micro" || exit 0

move() { # $1 = source, $2 = dossier de destination
  mkdir -p "$2" || return 1
  [ -e "$2/$1" ] && return 1 # destination déjà occupée : ne rien écraser
  git mv "$1" "$2/" 2>/dev/null || mv "$1" "$2/"
}

cur=$(date +%Y-%m)
moved=()

for d in [0-9]*-*/; do
  d="${d%/}"
  # Noms lus sur le disque : validés avant d'atteindre une commande.
  printf '%s' "$d" | grep -qE '^[0-9]{8}-[a-z0-9-]{1,60}$' || continue
  head -n 8 "$d/PLAN.md" 2>/dev/null | grep -qE '^status: *done *$' || continue
  m="archive/${d:0:4}-${d:4:2}"
  move "$d" "$m" || continue
  if [ -f INDEX.md ]; then
    # Hors de docs/micro, pour que mgrep watch ne voie pas de fichier temporaire.
    tmp=$(mktemp) && sed "s#](${d}/PLAN.md)#](${m}/${d}/PLAN.md)#" INDEX.md > "$tmp" \
      && cat "$tmp" > INDEX.md
    rm -f "$tmp"
  fi
  moved+=("$d")
done

for f in DAILY_LOG-*.md; do
  [ -e "$f" ] || continue
  m="${f#DAILY_LOG-}"; m="${m%-??.md}"
  printf '%s' "$m" | grep -qE '^[0-9]{4}-[0-9]{2}$' || continue
  [ "$m" = "$cur" ] && continue
  move "$f" "archive/$m" || continue
  moved+=("$f")
done

[ ${#moved[@]} -eq 0 ] && exit 0

# mgrep watch ne suit pas les déplacements de dossiers (il tente de supprimer
# le chemin du dossier, 404, et garde les fichiers sous l'ancien chemin).
# Une recherche avec -s resynchronise le store ; détachée pour ne pas retarder
# la session. Sautée si le quota Mixedbread est marqué épuisé.
if command -v mgrep >/dev/null 2>&1 && [ ! -f "$HOME/.claude/state/mgrep_quota.json" ]; then
  (cd "$cwd" && nohup mgrep search -s -m 1 "micro-dev plan index" docs/micro >/dev/null 2>&1 &)
fi

echo "micro-dev — balayage d'archive : ${#moved[@]} élément(s) déplacé(s) vers docs/micro/archive/ (${moved[*]}). Renommages non commités, à inclure dans le prochain commit."
exit 0
