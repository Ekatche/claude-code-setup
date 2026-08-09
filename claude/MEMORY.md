# MEMORY

Index des faits durables. **Une ligne par fait**, jamais de contenu ici.

Format : `- [Titre](nom-du-fichier.md) — accroche en une phrase`

Chaque fait vit dans son propre fichier sous `memory/`, avec ce frontmatter :

```yaml
---
name: <slug-en-kebab-case>
description: <résumé en une ligne — sert au rappel>
metadata:
  type: user | feedback | project | reference
---
```

Ce fichier est volontairement vide : la mémoire est privée et ne se
synchronise pas entre machines.
