# plugin-plugin

Plugin Claude Code qui construit des plugins Claude Code au modèle de [plugin-flutter](https://github.com/soonlysoul/plugin-flutter) : cadrage, création d'un plugin dédié et vert, composants ajoutés en TDD (skills avec leur évaluation, agents, hooks, déclaration d'un serveur MCP), publication dans la marketplace `soon` sous accord explicite, ré-audit après une mise à jour de Claude Code, reprise depuis le disque.

Version **0.1.0**, en construction. Le périmètre et l'ordre de construction sont fixés par [docs/PRD.md](docs/PRD.md) et [docs/PLAN.md](docs/PLAN.md) ; l'avancement, par [PROGRESS.md](PROGRESS.md). Claude Code **2.1.295 ou plus** requis (forme exec des hooks).

| Composant | Rôle |
| --- | --- |
| Skill `reaudit` | Sur demande (`/plugin-plugin:reaudit`) : les faits de la plateforme à revérifier depuis une mise à jour de Claude Code, les formats de composants changés, les faits que la validation stricte contredit |
| Skill `frame` | Cadre un nouveau plugin : une question à la fois, recommandation motivée, PRD et architecture approuvés explicitement avant tout fichier du plugin |
| Skill `create` | Crée le plugin dédié depuis le cadrage approuvé : nom vérifié sur GitHub, charpente du modèle, `git init`, suite du plugin créé lancée et verte |
| Skill `resume` | Reprend un travail interrompu depuis le disque — point de reprise, git, état du dépôt — en dix lignes au plus, sans rien modifier avant l'accord |
| Skill `add` | Ajoute un composant à un plugin du modèle, test vu en échec avant de passer ; un skill avec sa suite d'évaluation, annoncée et lancée seulement sur un « oui », un hook testé sur entrées simulées, après l'avertissement de portée, un agent aux outils déclarés, tenu à sa portée par un garde, ou la déclaration d'un serveur MCP existant, sans rien installer ni écrire de secret ; un composant hors périmètre est refusé, avec sa raison et ce qui le rouvrirait |
| Skill `check` | Liste les écarts d'un plugin au modèle — manifestes, fichiers à la racine, arborescence, forme des hooks, composants, harnais, fichiers parasites, identifiants en clair — sans rien modifier ; `add` refuse un plugin qui en a, et n'écrit dans un plugin qu'il n'a pas créé que le composant et son câblage |
| Skill `release` | Sur demande (`/plugin-plugin:release`) : répète la publication d'un plugin du modèle sans rien envoyer — refus si l'arbre, la validation stricte ou la suite ne sont pas verts, version selon la nature du changement, entrée du CHANGELOG, étiquette vérifiée, coût en contexte par composant, chaque geste avec sa commande exacte, commande d'installation — puis, à la demande, publie étape par étape, chacune lancée seulement après un « oui » tapé, reprise sans rien refaire après une coupure ; monte un plugin publié en sous-module d'un dépôt hôte |
| Hook `consent-capture` | Le message tapé juste après une étape annoncée est le seul accord : un « oui » littéral est consigné au journal des accords, toute autre réponse retire l'annonce ; inerte hors d'un projet géré ou sans annonce |
| Hook `gesture-guard` | Dans un dépôt de plugin géré ou une copie de la marketplace `soon`, un geste GitHub ne passe qu'une fois, s'il est la commande annoncée et accordée ; les gestes destructifs (suppression de dépôt, push forcé, réécriture d'historique, push sur `main` de la marketplace, fusion) sont refusés même accordés ; inerte ailleurs, mais présent dans toutes les sessions une fois le plugin installé |
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

Suite déterministe : bash et jq, sans réseau, sans session, sans quota. Elle lance les tests statiques, `claude plugin validate --strict` sur chaque cible (la marketplace, `plugin.json`, puis `skills/` et `agents/` s'ils existent) et mesure le coût en contexte permanent du plugin. Au-delà de 1 000 tokens, la suite de plugin-plugin échoue ; celle d'un plugin qu'il produit l'alerte et reste verte (`OVER_BUDGET` dans `tests/run-all.sh`).

| Code de sortie | Sens |
| --- | --- |
| 0 | tout passe |
| 1 | au moins une étape échoue |
| 2 | un prérequis manque (`jq`, ou `claude` pour la validation et le coût) : l'étape est bloquée, jamais comptée réussie |

Les tests sur les plugins réels — `check`, l'ajout à plugin-flutter, sa reconstruction, la réécriture de plugin-nixos — lisent les copies de lecture de `build/ref/` (ou `PP_REF_DIR`) et sont sautés sans elles.

## Reconstruire un plugin existant

```bash
bash scripts/pp.sh rebuild <dépôt d'origine> build/rebuild/<nom>
```

La charpente que plugin-plugin produit — manifestes, licence, `.gitignore`, `tests/lib.sh`, `tests/run-all.sh` —, puis tout le reste du dernier commit de l'original, tel quel. L'outil rapporte chaque écart entre sa charpente et celle de l'original, lance la suite de la reconstruction, et prouve l'original intact (HEAD, `git status`, empreintes). Il n'écrit que dans un dossier absent ou vide.

## La réécriture de plugin-nixos, un test

```bash
bash tests/rewrite/plugin-nixos.sh <dépôt de plugin-nixos> build/rewrite/plugin-nixos
```

Un test de plugin-plugin, jamais publié : `rebuild`, puis seulement ce que le modèle impose — hooks en forme exec sous `hooks/scripts/`, harnais du modèle —, chaque changement fermant un écart que `check` relève sur l'original. Elle prouve la suite portée verte, `check` à zéro écart, chaque cas de la suite d'origine présent dans la suite portée, et l'original intact. Lancée par `tests/integration/test_rewrite_nixos.sh`.

## Licence

MIT — voir [LICENSE](LICENSE).
