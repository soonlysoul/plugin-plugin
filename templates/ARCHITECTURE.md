# Architecture — <nom du plugin>

<date> · Soon · PRD : `docs/PRD.md`

**Statut : BROUILLON**

## Modèle

Plugin au modèle de plugin-flutter : dépôt dédié `soonlysoul/<nom>`, plugin à la racine, manifeste sans e-mail, licence MIT, marketplace locale `"source": "./"`, composants à la racine, tests dans `tests/`.

## Composants

Chaque composant répond à une user story ; aucun n'existe « au cas où ».

| Composant | Type | User stories | Pourquoi ce type | Coût permanent estimé |
| --- | --- | --- | --- | --- |
| `<nom>` | skill, agent, hook ou serveur MCP déclaré | US-… | <déterministe : hook ou script ; jugement : skill ; tâche bornée : agent> | <tokens> |

## Hooks

- Événement, filtre, mode (fail-open ou fail-closed) et contexte hors duquel le hook reste inerte.
- Un hook d'un plugin installé pour le compte s'applique à **toutes** les sessions.

## Agents

- Outils déclarés un par un, jamais `Agent` ; dossiers d'écriture et liste blanche Bash imposés par un garde de portée.

## Tests et évaluations

- Suite déterministe `tests/run-all.sh` : bash et jq, sans réseau ni quota.
- Une suite d'évaluation par skill : au moins un cas qui doit le déclencher, un qui ne le doit pas, trois exécutions par cas.

## Hors périmètre, et ce qui le rouvrirait

- <Composant écarté> — <raison> — rouvert si <déclencheur>.

## Décisions

- <Décision> — <raison> — <date>.
