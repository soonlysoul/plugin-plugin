# Sécurité — plugin-plugin

## Ce que plugin-plugin ne fait jamais

Même annoncé, même accordé :

- supprimer un dépôt ;
- forcer un push (`--force`, `-f`, `--force-with-lease`, `+réf`), supprimer une référence distante (`:réf`, `--delete`, `--mirror`) ;
- réécrire un historique publié (`filter-branch`, `filter-repo`) ;
- pousser sur `main` de la marketplace `soon`, qui ne change que par une PR ;
- fusionner une PR ;
- retirer un plugin de la marketplace : aucun chemin ne l'écrit.

## Les gestes GitHub : annoncés, accordés, une fois

Création de dépôt, push, push d'étiquette, PR : chaque étape de publication est annoncée par `pp.sh publish` avec ses commandes exactes, puis :

1. `consent-capture` (UserPromptSubmit, fail-open) lit le message tapé juste après. Un « oui » littéral est consigné dans `.plugin-plugin/consents.log` ; toute autre réponse, ou trente minutes sans réponse, retire l'annonce.
2. `gesture-guard` (PreToolUse, fail-closed) ne laisse passer un geste que s'il est la commande annoncée et que son accord est consigné ; l'annonce est alors consommée, le geste passe une fois. Le journal des accords ne s'écrit par aucun outil de Claude.

Les deux hooks ne dépendent pas l'un de l'autre : l'accord passe par le disque.

**Fail-closed** : `gesture-guard` sort en 2 sur toute erreur interne — `jq` absent, entrée illisible — et `hooks.json` déclare `"onFailure": "block"`, qui couvre aussi un script introuvable ou un délai dépassé. Il ne l'est que dans un dépôt de plugin géré ou une copie de la marketplace `soon` ; ailleurs il est inerte, même sans `jq`.

### Limites

`gesture-guard` arrête le geste tapé par erreur, pas un contournement délibéré : un script qui pousse lui-même, lancé par fichier, n'est pas lu. Il s'appuie sur les règles de permission et sur le garde de compte (`rm -rf` hors `build/`), qu'il ne remplace pas.

## Documents approuvés

`doc-status-guard` (PostToolUse, fail-open) compare un document de cadrage à l'empreinte enregistrée à son approbation : modifié, il repasse en REVUE, et Claude en est averti. `create` refuse un cadrage qui n'est pas approuvé.

## Évaluations

- Toujours `--no-publish` : sans lui, le rapport partirait sur claude.ai.
- Toujours un plafond `--max-cost-usd`, annoncé avec le nombre de sessions, le coût estimé et le compte qui paie, avant votre « oui ».
- Jamais `--trust-plugin`, que l'outil présente comme l'équivalent de `--dangerously-skip-permissions`.
- Un cas qui a besoin de Bash sans bac à sable appliqué est « bloqué », jamais « réussi ».

## Secrets

- Aucun secret dans un plugin produit : une valeur de l'utilisateur s'écrit `${VAR}`. `add` refuse de déclarer un serveur MCP avec un identifiant en clair.
- `check` signale un identifiant en clair par son fichier et sa ligne, jamais par sa valeur.
- Le manifeste porte `author.name` sans e-mail ; l'e-mail git n'est jamais recopié.

## Installations

Rien de ce que plugin-plugin exécute, ni de ce qu'il produit, ne lance une installation impérative (`npm install`, `pip install`, `bun install`). Le gabarit MCP de `claude plugin init`, qui lance `bun install` au démarrage, n'est jamais repris.

## Où plugin-plugin écrit

Dans le dossier du plugin cible qu'on lui nomme, sous `.plugin-plugin/` pour son état ; dans `build/` de son propre dépôt pour les reconstructions et les essais. Jamais dans `~/.claude`, jamais dans la racine du plugin installé. Les sondes du ré-audit tournent sous un HOME jetable.
