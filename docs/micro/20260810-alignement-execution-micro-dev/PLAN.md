---
task: Aligner l'exécution micro-dev entre harnais — trois gardes manquantes, prouvables par trois scénarios
status: blocked
created: 2026-08-10
---

# Alignement de l'exécution micro-dev entre harnais

## Constat — ce qui a divergé, et ce qui n'a pas divergé

Un plan micro-dev écrit par un harnais a été exécué par un autre, sur un dépôt
applicatif hors de ce repo. La suite de vérifications du projet est passée au
vert, le journal d'exécution était complet et bien formé. Une revue croisée du
diff par le premier harnais a trouvé **neuf défauts**, dont un fonctionnel :
un segment de chemin en trop qui figeait deux compteurs à zéro en permanence,
invisible pour la suite de tests.

Ce qui **n'a pas** divergé, vérifié avant de proposer quoi que ce soit :

```
~/.claude/skills/micro-dev                    -> <repo>/claude/skill-sources/micro-dev
~/.gemini/config/skills/micro-dev             -> <repo>/claude/skill-sources/micro-dev
~/.claude/skills/executing-micro-plans        -> .../executing-micro-plans
~/.gemini/config/skills/executing-micro-plans -> .../executing-micro-plans
```

Même octet des deux côtés. Le texte est déjà partagé. **Uniformiser le texte
n'est donc pas le levier** — il l'est déjà. Ce qui manque, ce sont trois gardes
que le texte ne contient pas encore.

### Cause 1 — le protocole lit des sections que le plan n'a pas

Le plan exécuté était dans un format antérieur (`## Plan` + `## Steps`, sans
frontmatter, sans `Definition of Done`, sans `Surgical Scope`).
`executing-micro-plans` lit ces sections **par leur nom**. Cinq de ses sept
phases visaient donc du vide : Phase 1 (lire `status`), Phase 2 (revue de la DoD
et du Surgical Scope), Phase 3 (baseline des commandes DoD), Phase 6 (teardown
borné aux `Symbols replaced`), Phase 7 (remplir `## Code Review`).

Seul le contrat de marqueurs `[~]`/`[x]` plus l'Execution Log ne dépend d'aucune
section. D'où l'artefact obtenu : un journal parfait, zéro garde. Le protocole
n'avait aucune instruction pour reconnaître un plan qu'il ne peut pas exécuter.

### Cause 2 — les conventions du dépôt ne sont pas dans le protocole

Un harnais ne charge automatiquement que les noms de fichiers qu'il connaît, à
la racine. Un fichier de convention nommé pour un autre harnais, ou imbriqué un
niveau plus bas — dans le paquet source plutôt qu'à la racine — lui est
invisible. Dans le cas observé, un `CLAUDE.md` imbriqué imposait une docstring
sur chaque signature publique et interdisait de supprimer du code sans en
connaître les appelants : le harnais exécutant ne l'a jamais lu. Deux défauts
sur neuf en découlent mécaniquement, sans mauvaise volonté.

Le protocole ne disait nulle part de lire les fichiers de convention du dépôt.
Il supposait que le harnais l'avait fait — ce qui n'est vrai que si le fichier
porte le nom que ce harnais-là connaît, à l'endroit où il regarde.

### Cause 3 — une exigence en prose n'a aucune garde

Le plan énonçait, en prose, des exigences de qualité d'interface : requête
`@media`, `:focus-visible`, libellé accessible sur les boutons, zéro CSS en
ligne, règle monospace pour les identifiants et sans-serif pour les phrases.
Aucune n'était une commande. Le format en vigueur exige que chaque item de DoD
soit « une commande exacte **ou** `n/a` avec raison » — une exigence de qualité
en prose n'entre dans aucune des deux cases, donc elle sort du plan. Cinq
défauts sur neuf viennent de ce trou.

Or elles étaient toutes vérifiables :

```bash
grep -c 'style="' <gabarit>          # attendu 0
grep -c 'focus-visible' <feuille>    # attendu > 0
```

Le compte `grep` **est** une commande. Il manquait la consigne de convertir.

## Simpler Alternative Considered

Trois options plus simples, écartées chacune pour une raison nommée :

1. **Migrer tous les anciens plans au format courant.** Traite le symptôme d'un
   plan sans installer aucune garde : le prochain plan étranger — écrit à la
   main, venu d'un autre dépôt, produit par une version antérieure — reproduira
   l'échec. Écartée. La migration d'un plan donné se fait séparément, elle ne
   dispense pas de la garde.
2. **Écrire les règles dans le fichier de contrat d'un seul harnais.** Corrige un
   harnais sur deux et fait diverger les deux textes — exactement ce que le
   partage par symlink existe pour empêcher. Écartée.
3. **Ne rien changer au texte, se reposer sur la revue croisée.** C'est ce qui a
   fonctionné cette fois : l'autre harnais a relu et trouvé les neuf défauts.
   Mais ça suppose qu'un second agent relise à chaque fois, ce qui n'est ni
   garanti ni gratuit. La revue croisée reste utile ; elle n'est pas une garde.

## Ordre de travail — les scénarios avant le texte

`superpowers:writing-skills` pose une Loi de Fer : pas de règle de skill sans un
test qui échoue d'abord. `micro-dev-tests/` existe précisément pour ça
(`run-scenario.sh`, `grade.sh`, bras `baseline` puis `skill`).

Les trois scénarios sont donc écrits **avant** les trois gardes, et non après.

**Limite assumée, à dire plutôt qu'à cacher** : le bras RED (baseline) exige de
dispatcher des sous-agents. La consigne de session l'interdit sans demande
explicite de l'utilisateur. Les trois gardes sont donc **écrites mais non
prouvées** à la fin de ce plan, et le plan le dit dans son verdict. Le premier
qui lance `./run-scenario.sh EX-6 baseline` clôt la mesure.

## Surgical Scope

- **Files touched** :
  - `claude/skill-sources/micro-dev-tests/fixtures/make-fixture.sh` — 3 fixtures
  - `claude/skill-sources/micro-dev-tests/run-scenario.sh` — mappage + `--list`
  - `claude/skill-sources/micro-dev-tests/grade.sh` — critères MD-6, EX-6, EX-7
  - `claude/skill-sources/micro-dev-tests/scenarios/micro-dev.md` — MD-6
  - `claude/skill-sources/micro-dev-tests/scenarios/executing-micro-plans.md` — EX-6, EX-7
  - `claude/skill-sources/executing-micro-plans/SKILL.md` — gardes 1, 2, 4
  - `claude/skill-sources/micro-dev/SKILL.md` — garde 3 (type d'item DoD)
  - `claude/skill-sources/micro-dev/references/PLAN_TEMPLATE.md` — garde 3
  - dans le dépôt applicatif visé : `AGENTS.md` — **nouveau**, symlink vers
    `CLAUDE.md`. Hors de ce repo, aucun fichier de ce repo n'en dépend.
- **Files NOT touched** : tout le reste. En particulier `gemini/AGENTS.md` et
  `gemini/GEMINI.md` (les règles vont dans la skill partagée, pas dans le
  contrat d'un seul harnais), `claude/settings.json`, et les hooks.
- **Symbols replaced** (→ à supprimer avant `done`) : aucun. Les trois scripts
  shell gagnent des branches `case`, aucune branche existante n'est remplacée.
- **Symbols extended** (→ garder, ajouter seulement) :
  - `scenario_fixture`, `scenario_skill`, `--list` dans `run-scenario.sh`
  - le `case "$FIXTURE"` de `make-fixture.sh`
  - le `case "$ID"` de `grade.sh`
  - Phases 1, 3 et 7 de `executing-micro-plans/SKILL.md`
  - la section `Definition of Done` de `micro-dev/SKILL.md` et du template

## Definition of Done

- [x] ① Syntaxe shell : `bash -n fixtures/make-fixture.sh && bash -n run-scenario.sh && bash -n grade.sh` — exit 0
- [x] ② Les 3 scénarios sont déclarés : `./run-scenario.sh --list` — 13 lignes, dont `MD-6`, `EX-6`, `EX-7`
- [x] ③ Les 3 fixtures se construisent : `./fixtures/make-fixture.sh plan-legacy-format`, `plan-house-rules`, `webpage` — exit 0 chacun, dépôt git avec exactement 1 commit
- [x] ④ Les 3 prompts s'extraient : `./run-scenario.sh EX-6 baseline`, `EX-7 baseline`, `MD-6 baseline` — sortie non vide, `{{REPO}}` substitué
- [x] ⑤ Les critères discriminent : `./grade.sh EX-6 <fixture-intacte>` — exit 1. Une fixture jamais touchée ne doit jamais passer (même exigence que `grade_plan_was_engaged` pour les scénarios existants)
- [x] ⑥ Les 3 gardes sont dans le texte partagé : `grep -c 'Format gate' executing-micro-plans/SKILL.md` > 0, idem pour la lecture des conventions et la revue de diff en Phase 7
- [x] ⑦ Le symlink de convention résout dans le dépôt visé : `readlink AGENTS.md` → `CLAUDE.md`, et une lecture du fichier via le symlink réussit
- [ ] ⑧ Mesure RED — **n/a dans ce plan**, exige le dispatch de sous-agents que la consigne de session interdit sans demande explicite. Le verdict dira `BLOCKED` sur ce point tant que la mesure n'a pas tourné.

## Steps

- [x] 1. Les 3 fixtures dans `make-fixture.sh` : `plan-legacy-format` (plan au
      format antérieur, sections courantes absentes), `plan-house-rules` (règle
      de docstring dans un `CLAUDE.md` imbriqué, jamais à la racine), `webpage`
      (gabarit HTML avec des exigences de qualité vérifiables au `grep`)
- [x] 2. Les 3 scénarios dans `scenarios/` + mappage et `--list` dans
      `run-scenario.sh`
- [x] 3. Les critères MD-6, EX-6, EX-7 dans `grade.sh` — dont le fait qu'une
      fixture intacte échoue
- [x] 4. Garde 1 (contrôle de format en Phase 1) + garde 2 (lecture des
      conventions du dépôt en Phase 3) + garde 4 (revue du diff et règle sur les
      tests neufs en Phase 7) dans `executing-micro-plans/SKILL.md`
- [x] 5. Garde 3 (troisième type d'item DoD : assertion exécutable pour toute
      exigence de qualité énoncée) dans `micro-dev/SKILL.md` et
      `references/PLAN_TEMPLATE.md`
- [x] 6. Dans le dépôt applicatif visé, `AGENTS.md` → `CLAUDE.md`, et vérifier
      que le lien résout à la lecture
- [x] 7. (teardown) `Symbols replaced` est vide : scan d'orphelins borné à
      l'ensemble vide, 0 orphelin par construction. Puis les 7 items ① à ⑦ de la
      DoD en une passe.

## Code Review
- **Dead code removed** : aucun à supprimer. `Symbols replaced` est vide, le scan d'orphelins est borné à cet ensemble vide : 0 orphelin par construction. Les 10 lignes supprimées par le diff sont toutes des renumérotations (`2.` → `3.` dans les phases 1, 3 et 7) ou un remplacement par une version étendue (la ligne `available:` de `make-fixture.sh`, la phrase de conclusion du tableau Bad/Good du template). Zéro contenu perdu — vérifié en relisant `git diff -U0 | grep '^-[^-]'` ligne à ligne.
- **Build status** : pas de build dans ce dépôt. `bash -n` sur les 3 scripts — exit 0. Les 3 fixtures se construisent, 1 commit chacune. Les 3 scénarios s'extraient avec `{{REPO}}` substitué.
- **Type errors** : `n/a` — dépôt de configuration, aucun code typé (shell et markdown).
- **Unintended side effects** : deux corrections de rendu markdown trouvées **par la revue de diff, pas par la DoD** — les insertions en Phase 1 et Phase 3 coupaient une liste ordonnée en deux, ce qui aurait fait redémarrer la numérotation à `1.` au rendu. Format gate sorti de la liste en bloc autonome, bloc de code de la Phase 3 indenté sous son item. C'est la garde 4 qui a attrapé ses propres auteurs.
- **Security surface touched** : non. Aucun fichier d'authentification, de secret ou de validation d'entrée. Le rappel semgrep du hook s'est déclenché sur `run-scenario.sh` et sur le template au motif d'un mot-clé présent dans le contexte — faux positif, les diffs concernés ajoutent des branches `case` de dispatch de scénario et une ligne de tableau markdown. `./scrub-check.sh` sur l'ensemble du contenu suivi : 0 violation hors `tests/fixtures/leaky.txt`, qui est la fixture de test du garde-fou lui-même.
- **Verdict** : ⚠️ BLOCKED — les 7 items mécaniques ① à ⑦ sont verts, mais la DoD ⑧ (mesure RED/GREEN) n'a pas tourné. Les trois gardes sont **écrites et outillées, pas prouvées**. Annoncé d'avance dans `## Ordre de travail`, pas découvert à la fin.

## Execution Log
- 2026-08-10T11:54Z | claude-code | preflight | baseline DoD : ① exit 0 · ② 10 lignes · ④ `unknown scenario: EX-6` · ⑦ symlink de convention absent
- 2026-08-10T11:57Z | claude-code | step 1 | done | `bash -n` exit 0 ; les 3 fixtures construites, 1 commit chacune (`plan-legacy-format`, `plan-house-rules`, `webpage`)
- 2026-08-10T11:57Z | claude-code | step 2 | started
- 2026-08-10T12:02Z | claude-code | step 2 | done | DoD ② `--list` = 13 lignes, `MD-6`/`EX-6`/`EX-7` présents · DoD ④ les 3 prompts s'extraient (7/6/11 lignes), 0 `{{REPO}}` restant, chemins de fixture substitués
- 2026-08-10T12:02Z | claude-code | step 3 | started
- 2026-08-10T12:05Z | claude-code | step 3 | done | DoD ⑤ dans les deux sens : fixture intacte `EX-6`/`EX-7`/`MD-6` → exit 1 chacune ; run correct simulé → exit 0 chacune (`route A — the gap was written into <plan>`, `slugify exists with a docstring`, `@media is asserted by a command`)
- 2026-08-10T12:05Z | claude-code | step 4 | started
- 2026-08-10T12:08Z | claude-code | step 4 | done | DoD ⑥ : `Format gate` 2 occurrences · `project's convention files` 1 · `Read the whole diff` 1 · `no external service running` 1. Phases 1/3/7 renumérotées, 3 lignes ajoutées aux Red Flags, 3 aux Rationalizations, 1 au Quick Reference
- 2026-08-10T12:08Z | claude-code | step 5 | started
- 2026-08-10T12:10Z | claude-code | step 5 | done | `requirement the user stated` : 1 occurrence dans `micro-dev/SKILL.md`, 3 dans `PLAN_TEMPLATE.md` (item de gabarit, ligne du tableau Bad/Good, checklist pré-exécution) ; `n/a` redéfini comme « outil absent », jamais « difficile à mesurer »
- 2026-08-10T12:10Z | claude-code | step 6 | started
- 2026-08-10T12:11Z | claude-code | step 6 | done | DoD ⑦ : `readlink AGENTS.md` → `CLAUDE.md` ; lecture par python3 réussie, `symlink: True | resolves: CLAUDE.md | bytes: 2181`
- 2026-08-10T12:11Z | claude-code | step 7 | started
- 2026-08-10T12:15Z | claude-code | step 7 | done | teardown : `Symbols replaced` vide, 0 orphelin par construction. DoD ① à ⑦ en une passe, toutes vertes : `bash -n` exit 0 · `--list` 13 lignes · 3 fixtures 1 commit chacune · 3 prompts 0 placeholder · 3 fixtures intactes exit 1 · gardes `Format gate` 3 / conventions 1 / diff 1 / tests offline 1 · `readlink AGENTS.md` = `CLAUDE.md`, lecture 2181 octets
- 2026-08-10T12:15Z | claude-code | plan | blocked | DoD ⑧ non mesurée : le bras RED exige le dispatch de sous-agents, interdit sans demande explicite de l'utilisateur
- 2026-08-10T12:34Z | claude-code | post-close | plan réécrit sans aucune mention de projet — ce repo est public, voir `## Notes`

## Notes

### Ce qui reste à faire : la mesure

Les trois gardes existent dans le texte et les trois scénarios existent dans le
rig, mais **aucun n'a été exécuté contre un agent**. L'ordre de travail annoncé
(scénarios d'abord, texte ensuite) a été respecté ; la Loi de Fer de
`writing-skills` ne l'est qu'à moitié : le test existe, le rouge n'a pas été
observé.

Ce qui clôt la mesure, quand l'utilisateur autorise le dispatch de sous-agents :

```bash
cd <repo>/claude/skill-sources/micro-dev-tests
./run-scenario.sh EX-6 baseline     # bras RED : le prompt part à un sous-agent sans la skill
./grade.sh EX-6 <fixture>           # doit ÉCHOUER — sinon le scénario ne prouve rien
./run-scenario.sh EX-6 skill        # bras GREEN
./grade.sh EX-6 <fixture>           # doit PASSER
```

Idem `EX-7` et `MD-6`. Un scénario dont le bras RED passe est à jeter : il
mesure quelque chose que l'agent faisait déjà.

### Une garde qui a attrapé son propre auteur

La garde 4 (« lire tout le diff en Phase 7 ») a trouvé deux défauts dans le diff
qui l'introduisait : les insertions en Phase 1 et Phase 3 coupaient une liste
ordonnée markdown en deux, ce qui aurait renuméroté la suite à partir de `1.`.
La DoD ⑥ était verte — elle comptait des occurrences de chaîne, elle ne lit pas
le rendu. C'est exactement l'écart entre « la DoD vérifie ce qu'on a pensé à
vérifier » et « le diff montre ce qu'on a fait », qui est l'argument écrit dans
la garde elle-même.

### Un manquement de procédure, à l'étape 1

L'étape 1 a été exécutée sans écrire `[~]` ni la ligne `started` dans
l'Execution Log **avant** le travail. Le protocole l'exige (Phase 4, points 1 et
2) : `[~]` est ce qui rend un plantage récupérable. Corrigé à partir de l'étape
2, où chaque étape a bien eu son `[~]` et sa ligne `started` avant son premier
edit. Consigné ici plutôt que passé sous silence : le marqueur manquant ne se
voit pas dans un journal rempli après coup, et c'est précisément la classe de
défaut que ce plan corrige chez les autres.

### Deux limites connues des critères de `grade.sh`

1. `MD-6` accepte tout hexadécimal différent de celui livré par la fixture comme
   « couleur d'accent enregistrée ». Sur le contre-test, un blanc pur a compté.
   Le critère reste correct — il exige qu'une couleur soit écrite pour que la DoD
   ait quelque chose à vérifier — mais il ne juge pas le contraste. Ce jugement
   appartient au `manual`.
2. `EX-6` route A (s'arrêter et demander) exige que le constat soit **écrit dans
   le fichier de plan**. `grade.sh` ne lit pas le transcript : un agent qui
   s'arrête en le disant seulement dans le chat serait noté FAIL. C'est pourquoi
   la garde 1 impose d'écrire les sections manquantes dans le fichier avant de
   s'arrêter. Même précédent que `EX-3`, qui exige déjà que le plan nomme le
   consommateur hors périmètre pour créditer la détection.

### Un fichier de convention imbriqué reste un angle mort

Un symlink `AGENTS.md` → `CLAUDE.md` à la racine du dépôt visé ne rend visible
l'imbriqué qu'indirectement, si la racine y renvoie. La commande `find` de la
garde 2 le trouve, elle — c'est là son intérêt : elle cherche à tous les
niveaux, pas seulement là où le harnais regarde. Un second symlink dans le
répertoire imbriqué rendrait la chose directe ; il n'était pas dans le
`Surgical Scope`, donc il n'a pas été créé. La dérive de périmètre est une
condition d'arrêt, pas une commodité.

### Pourquoi ce plan ne nomme aucun projet

Ce repo est **public**. La première version de ce plan nommait le dépôt
applicatif concerné à douze endroits, avec ses chemins de modules. Réécrite :
un plan versionné ici documente **ce qui change dans ce repo et pourquoi**, et
l'anecdote qui l'a motivé n'a besoin d'aucun nom propre pour être comprise.

Deux conséquences pratiques :

- `scrub-patterns.local` a été créé depuis son `.example`. Il était absent, et
  `scrub-check.sh` avertissait à chaque commit que les noms de projets privés
  n'étaient **pas** vérifiés. Le fichier est gitignoré par construction, donc
  il ne se propage pas : chaque machine doit le remplir, et y ajouter une ligne
  quand un nouveau projet privé arrive.
- Le `README` annonçait déjà « aucun nom de projet privé » sans mentionner
  `docs/`. La règle y est désormais explicite pour les plans.

Audit après réécriture : `./scrub-check.sh docs/` — 0 violation.
