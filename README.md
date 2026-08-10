# claude-code-setup

Reconfigure à l'identique, sur une machine neuve, les deux harnais de
développement assistés par IA utilisés ici : **Claude Code** (`~/.claude/`)
et **Antigravity / agy** (`~/.gemini/`).

## Ce que ce repo contient

- `claude/` : `CLAUDE.md`, `RTK.md`, `CONTEXT.md`, les hooks Claude Code, les
  agents, les sources de skills partagées (`micro-dev`,
  `executing-micro-plans`), et un `settings.json` scrubbé (chemins absolus
  remplacés par des variables d'environnement).
- `gemini/` : `GEMINI.md`, `AGENTS.md`, les hooks agy portant le même contrat
  que leurs équivalents Claude Code, les skills agy (dont deux nouvelles,
  `code-search` et `ast-grep-search`, qui documentent la doctrine de choix
  d'outil « par compétence »), et un modèle `mcp_config.json.example` sans
  aucune clé.
- `manifest.json` : la liste des marketplaces, plugins, CLI et dépendances
  Python attendues.
- `bootstrap.sh`, `sync.sh`, `drift-check.sh` : les trois scripts qui
  installent, resynchronisent et auditent la configuration (détail plus bas).
- `scrub-check.sh` : le garde-fou sécurité, exécuté en pre-commit et en CI.
- `docs/micro/` : les plans micro-dev des changements apportés **à ce repo**.
  Ils décrivent ce qui est amélioré ici et pourquoi. Un plan versionné ici ne
  nomme aucun projet, aucun dépôt applicatif et aucun chemin de module privé —
  l'anecdote qui a motivé un changement se raconte sans nom propre.

## Ce que ce repo ne contient pas

- Aucune mémoire, aucun état de session : `MEMORY.md` réel, `state/`,
  `projects/`, `todos/`, `history.jsonl` restent sur la machine, jamais dans
  le repo.
- Aucun secret : pas de clé API, pas de token, pas de fichier
  `mcp_config.json` réel — seulement un `.example` à placeholders.
- Aucun chemin absolu personnel (répertoire utilisateur macOS type `/Users`,
  ou volume externe monté type `/Volumes`), aucun nom de projet privé, aucun
  nom de machine.
- Aucun code tiers vendored : ce repo installe des plugins et marketplaces
  publics via leurs dépôts officiels, il ne les recopie pas. Voir `NOTICE`
  pour l'attribution du contenu qui s'en inspire directement.

## Installation

```bash
git clone <url-de-ce-repo> claude-code-setup
cd claude-code-setup
git config core.hooksPath .githooks
./bootstrap.sh
```

Avant la première installation, lisez **`PREREQUISITES.md`** : la liste des
outils et comptes (payants ou non) à avoir en place, et la procédure pour
renseigner vos propres clés API dans `mcp_config.json`.

`bootstrap.sh` crée des liens symboliques pour tout ce qui est commun entre
les machines (hooks, agents, skills, `CLAUDE.md`/`GEMINI.md`/`AGENTS.md`), et
copie les `settings.json` en fichiers réels indépendants — ils portent des
valeurs propres à chaque machine et doivent rester éditables localement sans
réécrire le repo. Le script est idempotent : le relancer ne casse rien, et
tout fichier préexistant est sauvegardé (`.bak.<horodatage>`) avant d'être
remplacé par un lien.

## `sync.sh` et `drift-check.sh`

Comme les fichiers partagés sont liés par symlink, les éditer sur la machine
édite directement le repo — pas de dérive possible pour eux. `sync.sh`
couvre uniquement ce qu'un symlink ne peut pas couvrir : il scrube et
rapatrie les `settings.json`, régénère `manifest.json` depuis l'état réel des
plugins installés, régénère `mcp_config.json.example` à partir des seuls
*noms* de serveurs MCP réels (jamais leurs valeurs), et signale les fichiers
nés directement sur la machine sans être liés au repo. Il scrube puis vérifie
avec `scrub-check.sh` avant d'écrire quoi que ce soit dans le repo — jamais
l'inverse.

`drift-check.sh` est en lecture seule : il rapporte les écarts entre l'état
réel de la machine et `manifest.json` (plugins, CLI manquantes, fichiers non
liés) sans rien corriger lui-même. Corriger silencieusement transformerait
une information en surprise.

## Sécurité

**Ce repo est public.** `scrub-check.sh` tourne en hook pre-commit local
(`.githooks/pre-commit`, activé par `git config core.hooksPath .githooks`) et
en CI (`.github/workflows/ci.yml`) sur chaque push et pull request. Aucune
clé API, aucun chemin absolu personnel, aucun identifiant de machine n'est
censé jamais atteindre un commit — s'il en existe un malgré tout, ce sont des
bugs de `scrub-check.sh` à corriger, pas des exceptions à contourner.

## Attribution

Certaines skills et documents de ce repo s'inspirent de projets tiers sous
licence MIT. Voir `NOTICE` pour le détail des attributions.
