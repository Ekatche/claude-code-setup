# Prérequis

Ce repo ne installe aucun logiciel tiers : il reconfigure un poste qui a déjà
les outils suivants. Installez-les avant de lancer `./bootstrap.sh`.

## Gestionnaire de paquets

Sur macOS, [Homebrew](https://brew.sh) est le chemin le plus simple pour
installer la plupart des dépendances ci-dessous (`brew install jq gh`, etc.).
Sur Linux, utilisez le gestionnaire de paquets de votre distribution ou les
installeurs officiels de chaque outil.

## `jq`

Requis par `bootstrap.sh`, `sync.sh`, `drift-check.sh` et par la quasi-totalité
des hooks des deux harnais (ils parsent du JSON en shell). `brew install jq`
ou équivalent. Sans `jq`, `bootstrap.sh` échoue dès la lecture du manifeste.

## `rtk` (Rust Token Killer)

Proxy CLI qui réécrit `cat`/`ls`/`git`/`grep`/`find` de façon transparente et
mesure l'économie de tokens. Voir `claude/RTK.md` une fois le repo installé
pour la procédure d'installation et la vérification (`rtk --version`,
`rtk gain`).

## `mgrep` et un compte Mixedbread

Recherche sémantique de code, outil de premier rang dans la doctrine décrite
par `claude/CONTEXT.md`. Nécessite un compte payant chez Mixedbread : **aucune
clé n'est fournie par ce repo, créez votre propre compte et configurez votre
propre accès.**

## `ast-grep`

Recherche structurelle par motif AST (binaire parfois appelé `sg`). Seul outil
capable de matcher une forme de code plutôt qu'un texte littéral.
`brew install ast-grep` ou voir la documentation officielle du projet.

## `gh` (GitHub CLI)

Requis pour les opérations `git`/GitHub courantes et pour certains flux de
revue de code référencés dans les agents. `brew install gh`, puis
`gh auth login`.

## Tavily (`tvly`)

Recherche web avec synthèse sourcée multi-sources. Nécessite un compte Tavily
et une clé API personnelle : **aucune clé n'est fournie par ce repo, créez
votre propre compte et votre propre clé.** La clé sera renseignée dans
`~/.gemini/config/mcp_config.json` (voir procédure plus bas), jamais commitée.

## Firecrawl

Scraping et parsing de pages web (JS-rendu, PDF/DOCX/XLSX locaux, crawl
récurrent). Nécessite un compte Firecrawl et une clé API personnelle :
**aucune clé n'est fournie par ce repo, créez votre propre compte et votre
propre clé.** Même remarque que pour Tavily : la clé va dans
`mcp_config.json`, jamais dans le repo.

## Environnement Python token-savior

`bootstrap.sh` s'attend à un venv dédié (voir `manifest.json` →
`python.venv`, `$HOME/.local/token-savior-venv`) contenant le paquet
`token-savior-recall` à la version épinglée dans le manifeste. Créez-le avec
`python3 -m venv "$HOME/.local/token-savior-venv"` puis installez le paquet
avec `pip install "token-savior-recall==<version du manifeste>"`.

## Antigravity (agy)

Le harnais `~/.gemini/` est celui de l'application Antigravity. Installez
l'application Antigravity pour obtenir la CLI `agy` — sans elle, l'étape
Antigravity de `bootstrap.sh` est simplement ignorée avec un message
d'avertissement, le reste de l'installation continue.

## Remplir `mcp_config.json`

Aucun secret ne figure dans ce repo. `gemini/config/mcp_config.json.example`
ne contient que des placeholders (`<FIRECRAWL_API_KEY>`, `<TAVILY_API_KEY>`).
Après `./bootstrap.sh`, un `mcp_config.json` est créé depuis ce modèle à
`~/.gemini/config/mcp_config.json` (ou `$GEMINI_DIR/config/mcp_config.json`) —
ouvrez ce fichier et remplacez chaque placeholder par votre propre clé
personnelle. Ce fichier est gitignoré : vos clés n'entreront jamais dans
l'historique git.

## Motifs privés de scrub-check (optionnel)

Si votre nom de projet, votre nom de machine ou d'autres identifiants privés
doivent être détectés par `scrub-check.sh` en plus des motifs génériques déjà
committés, copiez `scrub-patterns.local.example` vers `scrub-patterns.local`
(à la racine du repo) et ajoutez vos propres motifs. Ce fichier est
gitignoré : il reste local à votre machine.
