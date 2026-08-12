# Contrat mémoire & contexte

Plusieurs systèmes de mémoire coexistent sur cette machine. Sans contrat ils se
recouvrent : le même fait finit stocké trois fois, ou nulle part. Un rôle par
outil, pas deux.

## Règle unique

**L'état vit sur disque, jamais uniquement dans le contexte.**

Le contexte est un cache volatil : un auto-compact, un `/clear` ou un crash
l'efface. Tout ce dont la suite du travail dépend doit exister comme fichier ou
comme entrée indexée avant que tu passes à l'étape suivante — pas après.

## Un rôle par outil

| Besoin | Outil | Durée de vie |
|---|---|---|
| Sortie trop grosse pour le contexte | `ctx_execute_file` — analyse dans le sandbox, seul ce que tu log entre | l'appel |
| « Qu'est-ce qui a été décidé / tenté avant ? » | `ctx_search(sort:"timeline")` | session, survit au compact |
| Fait durable sur l'utilisateur ou le projet | fichier mémoire + ligne dans `MEMORY.md` | permanent |
| État d'un travail en cours | fichier de plan sur disque (micro-dev) | permanent |

Ne mets pas un dump brut dans `MEMORY.md` (c'est un index, une ligne par fait).

La capture token-savior (`ts://capture/N`) a été retirée le 2026-08-08 : elle
annonçait des outils de relecture (`capture_search`, `capture_get`) qui
n'existent pas, et `ListMcpResourcesTool` ne renvoie aucune ressource — les
octets partaient dans le contexte **et** dans une capture illisible. Ne pas la
réactiver sans vérifier que la relecture fonctionne.

## Avant de demander à l'utilisateur

Sur reprise de session ou juste après un compact, `ctx_search` avant de poser la
question : décisions, erreurs, plans et prompts utilisateur sont capturés
automatiquement et indexés. Redemander ce qui est déjà indexé coûte un tour et
de la confiance.

## Auto-compact

Le compact déclenche à 200 000 tokens (`CLAUDE_CODE_AUTO_COMPACT_WINDOW` ×
`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, cf. `settings.json`). Il résume — il ne
préserve pas le détail. Ce qui n'est pas sur disque au moment du compact est
perdu, y compris à l'intérieur d'un subagent : le seuil s'applique aussi à eux.

Conséquence pratique, pas une suggestion : avant toute opération longue
(fan-out de subagents, boucle de build, exploration large), écris l'état
courant dans le fichier de plan. Le hook `SessionStart matcher:compact`
réinjecte des **pointeurs** vers cet état, jamais son contenu.

## Choix d'outil : par compétence, pas par prix

Tenu par les hooks, pas par la bonne volonté. Le principe n'est pas « le moins
cher d'abord » — c'est **le bon instrument d'abord**. L'abonnement Mixedbread
est payé : mgrep passe en tête là où il est le meilleur outil, et nulle part
ailleurs. Dépenser un crédit pour localiser un symbole dont on connaît déjà le
nom, c'est du gaspillage, pas de la priorisation.

### Code

| Besoin | Outil | Rang |
|---|---|---|
| Question sémantique en langage naturel | `mgrep '<question>'` | **1er** |
| ↳ quota épuisé, ou besoin de rester gratuit | `mcp__token-savior__search_codebase` | repli |
| Symbole précis dont tu connais le nom | `mcp__token-savior__find_symbol` | exact, gratuit |
| Appelants / appelés | `mcp__token-savior__get_call_chain` | gratuit |
| Motif structurel (forme de code) | `ast-grep -p '<motif>' -l <lang>` | seul capable |
| Structure d'un fichier | `ast-grep outline -l <lang> <file>` | zéro Read |
| Projet équipé d'un graphe | `mcp__code-review-graph__*` | project-scope |
| Texte littéral exact | `rtk grep '<texte>' <path>` | après un appel supérieur |

`grep`, `rg`, `find -name` bruts et le tool `Grep` natif sont bloqués tant
qu'aucun appel supérieur n'a eu lieu dans le tour.

### Web

Cinq fournisseurs installés, tous vivants. Le partage n'est pas « lequel est
le meilleur moteur » mais « la tâche est-elle *répondre à une question* ou
*récupérer des octets* ». Ce sont deux métiers.

**Répondre à une question :**

| Besoin | Outil |
|---|---|
| Doc d'une lib / SDK / CLI / framework | Context7 (`resolve-library-id` → `query-docs`) — meilleur sur la compétence : versionné et autoritatif, pas seulement gratuit |
| Question web générale | `mgrep --web '<question>'` — **1er choix** |
| ↳ quota Mixedbread épuisé | `WebSearch` |
| Rapport sourcé, synthèse multi-sources avec citations (30-120 s) | `tvly research '<sujet>'` — seul capable |

**Récupérer des octets :**

| Besoin | Outil |
|---|---|
| URL déjà connue | `WebFetch` — gratuit, essaie d'abord |
| Page rendue en JS, `WebFetch` revient vide, ou plusieurs pages d'un même site | `firecrawl scrape <url>` / `firecrawl crawl <url>` |
| Lister les URL d'un domaine sans en lire le contenu | `firecrawl map <domaine>` |
| PDF / DOCX / XLSX **local** vers markdown | `firecrawl parse <fichier>` — seul capable |
| Scrape récurrent avec détection de changement | `firecrawl monitor` — seul capable |
| Interagir avec une page (clic, JS) | `firecrawl interact`, ou `mcp__claude-in-chrome__*` si la session navigateur de l'utilisateur compte |

Les commandes `tvly search` / `tvly extract` / `tvly crawl` / `tvly map` et
`firecrawl search` doublonnent les lignes ci-dessus. Ne les appelle pas : le
doublon n'apporte rien et consomme des crédits sur deux comptes au lieu d'un.

**Piège de déclenchement.** Les plugins `tavily` (8 skills) et `firecrawl`
(10 skills) déclarent des descriptions volontairement agressives — `tavily-dynamic-search`
va jusqu'à « This is the default skill for web research ». Elles ne le sont pas.
Le tableau ci-dessus prime sur la description d'une skill ; une description est
écrite par son auteur pour maximiser son propre déclenchement, pas pour arbitrer
entre outils concurrents installés sur cette machine.

`websearch-priority-reminder.sh` accepte Context7, `mgrep --web`, `tvly` et
`firecrawl` comme tentative supérieure : le gate empêche le réflexe `WebSearch`,
il n'impose pas un fournisseur.

### Quota Mixedbread

`mgrep-quota-detect.sh` (PostToolUse Bash) repère un échec de crédit dans la
sortie de mgrep et écrit `~/.claude/state/mgrep_quota.json`. Les blocages se
lèvent alors seuls pendant 24 h — mettre mgrep en tête n'a de sens que si le
repli est automatique. Après recharge : `rm ~/.claude/state/mgrep_quota.json`.

### Handoff vers Antigravity (agy)

`agy -p "<tâche>" --output-format json` délègue une exécution à Antigravity
(headless, non-interactif). Jamais déclenché par un hook automatique — c'est
une action payante à quota invisible au moment de l'appel, donc toujours
initiée explicitement (par moi avec confirmation, ou par l'utilisateur),
même logique que `/code-review ultra`.

**Quota** : pas de commande CLI dédiée (`/usage` existe mais est une slash
command interactive, inutilisable en headless). Contournement vérifié le
2026-08-12 : `agy-statusline.sh` (référencé par
`~/.gemini/antigravity-cli/settings.json` → `statusLine.command`) reçoit le
payload JSON d'agy sur stdin à chaque changement d'état — **y compris en
mode headless** — et le persiste dans `~/.claude/state/agy_quota.json`.
Lire ce fichier avant un handoff donne un quota récent (dernier run agy),
jamais garanti temps réel — même limite que `mgrep-quota-detect.sh` côté
snapshot. Champs utiles : `.quota.<bucket>.remaining_fraction`,
`.quota.<bucket>.reset_in_seconds`, `.plan_tier`, `.model`.

Deux buckets de quota observés, semblent séparés par famille de modèle :
`gemini-5h`/`gemini-weekly` (modèles Gemini) vs `3p-5h`/`3p-weekly`
(modèles tiers — Claude, gpt-oss). Router vers un bucket qui a de la marge
plutôt que celui déjà entamé quand la tâche le permet.

**Modèles disponibles** (`agy models`) — pas de défaut documenté, toujours
passer `--model` explicite pour un handoff prévisible :

| Modèle | Contexte / effort | Bucket | Cas d'usage |
|---|---|---|---|
| `gemini-3.6-flash-high` | 1M tokens, effort high | gemini | Défaut agy. Gros repo, beaucoup de fichiers à ingérer, bon rapport vitesse/qualité |
| `gemini-3.6-flash-medium`/`low` | 1M tokens | gemini | Tâche mécanique/simple, priorité vitesse sur qualité |
| `gemini-3.5-flash-high`/`medium`/`low` | ~1M tokens (génération précédente) | gemini | Repli si 3.6 indisponible ou bucket gemini à sec |
| `gemini-3.1-pro-high`/`low` | raisonnement "Pro", pas de tier medium | gemini | Analyse qui a besoin de plus de profondeur qu'un Flash |
| `claude-sonnet-4-6` | 250k tokens, thinking | 3p | Code complexe, refactor — même famille que Claude Code, cohérence de style |
| `claude-opus-4-6-thinking` | thinking, plus capable que sonnet | 3p | Tâche la plus dure : architecture, debug profond, quand sonnet insuffit |
| `gpt-oss-120b-medium` | open-weight OpenAI | 3p | Second avis / perspective différente, ou repli si gemini+claude buckets épuisés |

Tailles de contexte confirmées par payload réel : `gemini-3.6-flash-high` =
1 048 576 tokens, `claude-sonnet-4-6` = 250 000 tokens. Le reste est déduit
du nom du modèle, pas mesuré.

### Outil ou MCP mal configuré

Différent du quota : une config absente (clé API manquante, projet non
enregistré, serveur MCP inaccessible) ne se corrige pas toute seule. Pas de
repli silencieux légitime ici — le seul comportement correct est de le dire à
l'utilisateur et de proposer de l'aider à corriger, jamais de continuer comme
si de rien n'était ni d'abandonner sans un mot.

`tool-config-not-set.sh` (PostToolUse `Bash|mcp__.*`) détecte quatre cas et
injecte la marche à suivre exacte (fichier à éditer, section de
`PREREQUISITES.md`, qui doit agir) :

| Cas détecté | Signal | Fix documenté |
|---|---|---|
| `token-savior` sans projet enregistré | `No projects registered` | `WORKSPACE_ROOTS` dans `~/.claude.json` — `PREREQUISITES.md` § Environnement Python token-savior |
| `mgrep` sans session valide (≠ quota) | `unauthorized`, `401`, `please mgrep login` | `mgrep login` — l'utilisateur le lance lui-même, flux OAuth |
| `tvly` / `firecrawl` (CLI) sans clé | `api key`, `401` | `~/.gemini/config/mcp_config.json` — `PREREQUISITES.md` § Remplir mcp_config.json |
| Serveur MCP générique down | `ENOENT`, `MCP error`, `server disconnected` | vérifier `~/.claude.json` ou `mcp_config.json` selon le harnais |

État : `~/.claude/state/tool_config_alerts.json`, throttle 10 min par clé —
anti-spam seulement, jamais un cache de statut « réparé ». Réinitialisation :
`rm ~/.claude/state/tool_config_alerts.json`.

## Doublons : qui pilote

Plusieurs outils installés font un travail voisin. Un seul pilote par besoin,
les autres ne sont appelés que dans le cas qu'ils sont seuls à couvrir.

### Review

| Cas | Qui pilote |
|---|---|
| Pull request GitHub | `/code-review <PR#>` — commande du plugin officiel, tourne sur `gh pr diff`, poste le commentaire |
| Review multi-agents lourde, branche ou PR | `/code-review ultra` — déclenché par l'utilisateur, facturé. Je ne le lance pas moi-même |
| Diff local non commité, un fichier, une branche sans remote | `caveman:cavecrew-reviewer` — le plugin officiel ne sait pas faire, il ne lit que `gh pr diff` |
| Sécurité (SAST, secrets, supply chain) | `mcp__plugin_semgrep_guardian__*` |

`feature-dev:code-reviewer` n'est pas appelé seul : c'est une étape interne du
pipeline `feature-dev`. `code-simplifier` n'est pas un reviewer — il réécrit
pour la clarté à fonctionnalité constante, ne l'appelle pas pour chercher des
bugs.

### Création et modification de skills

`skill-creator` pilote, `superpowers:writing-skills` fournit la doctrine.

Ce n'est pas un compromis : les deux ne couvrent pas la même moitié du travail.
`skill-creator` apporte le seul appareil de mesure disponible — runs A/B
with-skill contre baseline, `aggregate_benchmark.py` (pass rate, tokens, durée,
moyenne ± écart-type), viewer HTML de relecture, et `improve_description.py`
qui mesure la précision de déclenchement sur 20 requêtes. `writing-skills`
n'a aucune de ces mesures, mais il a ce que `skill-creator` n'a pas : la
Loi de Fer (pas de skill sans baseline rouge d'abord), la table
« match the form to the failure » qui dit *quelle forme* d'instruction
corriger quel type d'échec, et les tables de rationalisation.

Donc : boucle et métriques par `skill-creator`, décisions de contenu par
`writing-skills`. Le RED baseline exigé par la Loi de Fer est exactement le run
`without_skill` de `skill-creator` — ce sont les deux noms d'une même chose, il
n'y a rien à faire deux fois.

## Lecture de fichiers

`Read` sans `offset`/`limit` sur plus de 500 lignes est bloqué. Localise
d'abord (`ast-grep outline`, `find_symbol`), lis ensuite la zone. Pour analyser
sans conserver les octets, `ctx_execute_file` : seul ce que tu log entre en
contexte.

## Commandes shell

`rtk` réécrit déjà `cat`, `head`, `ls`, `tree`, `find`, `du`, `wc`, `git` de
façon transparente via le hook `PreToolUse Bash`. N'écris pas de contournement
et n'appelle pas `rtk proxy` pour éviter la compaction — c'est un outil de
debug de rtk lui-même.
