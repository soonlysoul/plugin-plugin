# plugin-plugin

Plugin Claude Code qui construit des plugins Claude Code au modèle de [plugin-flutter](https://github.com/soonlysoul/plugin-flutter) : cadrage, création d'un plugin dédié et vert, composants ajoutés en TDD (skills avec leur évaluation, agents, hooks, déclaration d'un serveur MCP), publication dans la marketplace `soon` sous accord explicite, ré-audit après une mise à jour de Claude Code, reprise depuis le disque.

Version **0.1.0**, en construction. Le périmètre et l'ordre de construction sont fixés par [docs/PRD.md](docs/PRD.md) et [docs/PLAN.md](docs/PLAN.md) ; l'avancement, par [PROGRESS.md](PROGRESS.md). Claude Code **2.1.295 ou plus** requis (forme exec des hooks).

| Composant | Rôle |
| --- | --- |
| Skill `reaudit` | Sur demande (`/plugin-plugin:reaudit`) : les faits de la plateforme à revérifier depuis une mise à jour de Claude Code, les formats de composants changés, les faits que la validation stricte contredit |
| Skill `frame` | Cadre un nouveau plugin : une question à la fois, recommandation motivée, PRD et architecture approuvés explicitement avant tout fichier du plugin |
| Skill `create` | Crée le plugin dédié depuis le cadrage approuvé : nom vérifié sur GitHub, charpente du modèle, `git init`, suite du plugin créé lancée et verte |
| Skill `resume` | Reprend un travail interrompu depuis le disque — point de reprise, git, état du dépôt — en dix lignes au plus, sans rien modifier avant l'accord |
| Skill `add` | Ajoute un composant à un plugin du modèle, test vu en échec avant de passer ; en 0.1.0 : un skill avec sa suite d'évaluation, annoncée et lancée seulement sur un « oui » |
| Hook `doc-status-guard` | Un document de cadrage approuvé puis modifié repasse en revue ; inerte hors d'un projet portant `.plugin-plugin/`, mais présent dans toutes les sessions une fois le plugin installé |
| Hook `checkpoint-reminder` | En fin de tour, rappelle une fois un point de reprise plus ancien que le dernier commit ou qu'un fichier modifié ; inerte hors d'un projet géré |
| `scripts/pp.sh` | L'outil déterministe appelé par les skills, testé sans session |
| `scripts/facts/` | La base de faits datée et versionnée, ses sondes et les instantanés de formats |

## Essai local

Prérequis : Claude Code ≥ 2.1.295, `git`, `jq`.

Depuis la racine d'un clone de ce dépôt :

```bash
claude --plugin-dir .
```

La 0.1.0 n'est pas publiée : la première version installable depuis la marketplace `soon` sera la 0.1.1.

## Tests

```bash
bash tests/run-all.sh
```

Suite déterministe : bash et jq, sans réseau, sans session, sans quota. Elle lance les tests statiques, `claude plugin validate --strict` sur chaque cible (la marketplace, `plugin.json`, puis `skills/` et `agents/` s'ils existent) et mesure le coût en contexte permanent du plugin, qui doit rester sous 1 000 tokens.

| Code de sortie | Sens |
| --- | --- |
| 0 | tout passe |
| 1 | au moins une étape échoue |
| 2 | un prérequis manque (`jq`, ou `claude` pour la validation et le coût) : l'étape est bloquée, jamais comptée réussie |

## Licence

MIT — voir [LICENSE](LICENSE).
