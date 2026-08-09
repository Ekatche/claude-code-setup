# Règles Globales (Tous les projets)

## Processus micro-dev
- Avant de commencer toute petite tâche de développement (correction de bug, micro-fonctionnalité, petit refactor) ou lors d'une question technique nécessitant d'éditer du code, tu DOIS systématiquement demander à l'utilisateur : *"Voulez-vous que j'utilise la skill `micro-dev` pour traiter cette demande ?"*
- Si la réponse est oui, tu dois strictement appliquer le workflow de la skill `micro-dev` (avec le journal quotidien).

## Choix d'outil : par compétence, pas par prix

L'abonnement mgrep est payé : il passe en tête **là où il est le meilleur
instrument**, et nulle part ailleurs.

- **Question sémantique en langage naturel** : `mgrep '<question>'` — premier choix.
- **Motif structurel, forme de code** : `sg -p '<motif>' -l <lang>` — seul capable.
- **Structure d'un fichier** : `sg outline -l <lang> <fichier>` — zéro lecture intégrale.
- **Texte littéral exact** : `rtk grep '<texte>' <chemin>`, une fois l'un des précédents appelé.

`grep`, `rg` et `find -name` bruts sont **bloqués** par un hook tant qu'aucun
appel supérieur n'a eu lieu dans le tour. Ce n'est pas une recommandation : la
commande n'est pas exécutée.

Ne lis jamais un fichier en entier pour y chercher quelque chose. Localise
d'abord (`sg outline`, `mgrep`), lis ensuite la zone.

## Communication et Langue
- **Discussion** : Tu dois TOUJOURS t'adresser à moi en Français.
- **Code et Commentaires** : Le code (noms de variables, fonctions) et les commentaires dans les fichiers sources doivent TOUJOURS être rédigés en Anglais, sauf indication contraire explicite.
- Ne ré-explique jamais une évidence. Sois concis, va droit au but dans tes réponses.

## Sécurité et Actions Destructrices
- Tu n'as PAS le droit d'exécuter des commandes destructrices sans me demander une confirmation explicite et spécifique (ex: `rm -rf`, `git push --force`, `drop database`).
- Ne jamais exposer de clés API, mots de passe ou secrets en clair dans les logs, les artifacts ou le code que tu proposes. Utilise toujours des variables d'environnement (ex: `process.env.API_KEY`).

## Qualité du Code
- Lors d'une modification de fichier, tu dois préserver TOUS les commentaires et les annotations de typage existants qui ne sont pas directement impactés par la modification.
- N'invente pas de nouvelles librairies. Vérifie toujours le fichier `package.json` ou `requirements.txt` pour utiliser les outils déjà présents dans le projet avant d'en proposer de nouveaux.
- Propose du code typé de manière stricte (TypeScript, Python Type Hints) par défaut.

## Git et Historique
- Si je te demande de faire un commit, utilise toujours la convention "Conventional Commits" (ex: `feat:`, `fix:`, `chore:`, `refactor:`).
- Rédige les messages de commit en Anglais, à l'impératif, de manière claire et concise.

