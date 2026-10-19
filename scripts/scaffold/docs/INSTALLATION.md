# Installation — __NAME__

Claude Code **2.1.295 ou plus** requis.

## Essai sans installation

Depuis la racine d'un clone :

```bash
claude --plugin-dir .
```

Le plugin vaut pour cette session seule, sous le nom `__NAME__@inline`.

## Depuis la marketplace `soon`

Une fois le plugin publié :

```bash
claude plugin marketplace update soon
claude plugin install __NAME__@soon
```

Mise à jour : `claude plugin marketplace update soon`, puis `claude plugin update __NAME__@soon`.
