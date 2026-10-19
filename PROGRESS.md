# PROGRESS — plugin-plugin v0.1

Dernière mise à jour : 2026-10-19
Reprise : lire ce fichier, puis `git log --oneline` ; le plan fait foi (`docs/PLAN.md`, APPROUVÉ).

## État courant

Branche de travail `feat/v0.1.0`. **Phase 1 terminée** : plugin-plugin 0.1.0 vide, chargeable, suite déterministe verte. Prochaine étape : phase 2, base de faits et ré-audit.

Mesures de référence : Claude Code 2.1.296.

## Phase 1 — Amorce — terminée

- [x] Manifestes au modèle : `plugin-plugin` 0.1.0, `author.name` « Soon » sans e-mail, MIT, `homepage` = `repository` = `https://github.com/soonlysoul/plugin-plugin` ; marketplace locale `"source": "./"` ; LICENSE, README, CHANGELOG (0.1.0 en cours), `.gitignore` (`build/`, `evals/**/results/`).
- [x] La suite sort en 0 ; les sorties 1 (manifeste faussé, manifeste absent) et 2 (jq absent, claude absent) sont vérifiées par `tests/static/test_run_all.sh`.
- [x] `validate --strict` passe sur `.` et `.claude-plugin/plugin.json` ; `skills/` et `agents/` absents sont « sautés », jamais réussis ; un manifeste absent échoue.
- [x] Coût permanent affiché ; échec au-delà de 1 000 tokens ; « bloqué » sans `claude`.
- [x] Sondes consignées ci-dessous.
- [x] Le hook Stop du projet (`.claude/hooks/verify-tests.sh`) signale un `.sh` modifié ou nouveau et propose `bash tests/run-all.sh`.

### Sondes

| Sonde | Commande | Résultat |
| --- | --- | --- |
| `homepage` vers un dépôt GitHub inexistant | `gh api repos/soonlysoul/plugin-sonde-zz-inexistant` | 404 : le dépôt n'existe pas |
| | `claude plugin validate .claude-plugin/plugin.json --strict` (plugin de sonde) | exit 0, « Validation passed » |
| | `claude --plugin-dir <sonde> plugin details plugin-sonde-zz` | exit 0 |
| | `claude --plugin-dir <sonde> plugin list` | `plugin-sonde-zz@inline`, « ✔ loaded » |
| `plugin details` par `--plugin-dir` | `claude --plugin-dir build/ref/plugin-flutter plugin details plugin-flutter` | exit 0 en 0,9 s, sans session ; « Always-on: ~841 tok », stable sur trois lancements |
| | même commande sous `unshare -rn` (aucun réseau ; `curl` y sort en 7) | exit 0, mais « Always-on: ~617 tok » : environ 27 % de moins, sur chaque composant |

Conséquences :

- **`homepage` et `repository` entrent dès 0.1.0** : un dépôt encore inexistant n'empêche ni la validation stricte ni le chargement.
- **`plugin details` ne consomme pas de quota** : il répond sans réseau. Mais son estimation **dépend du réseau** : en ligne, elle passe vraisemblablement par un comptage distant (non prouvé), hors ligne par une heuristique plus basse. La suite garde la mesure telle quelle : la référence du budget (plugin-flutter, environ 830) est une mesure en ligne, et la mesure en ligne est la plus haute. À reprendre dans la base de faits (phase 2).
- Le garde de l'ancien flutter-forge a refusé un `rm -rf` dans le dossier temporaire de la session, comme prévu par le plan : non contourné, la sonde a pris un dossier neuf.

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/run-all.sh` (avant les manifestes) | 1 | `test_manifest : 3 réussis, 5 échoués` — « manifeste absent : .claude-plugin/plugin.json », « manifeste absent : .claude-plugin/marketplace.json », LICENSE, README, CHANGELOG ; `test_verify_tests_hook : 2 réussis, 3 échoués` ; bilan « échouées : 5 » |
| ROUGE | `bash tests/static/test_run_all.sh` (cas ajoutés) | 1 | « manifeste absent : sa validation échoue » et « … n'est jamais sautée » en échec : `run-all.sh` sautait la validation d'un `plugin.json` absent, défaut corrigé |
| VERT | `bash tests/run-all.sh` | 0 | `test_manifest : 26 réussis`, `test_run_all : 21 réussis`, `test_verify_tests_hook : 5 réussis` ; validation `ok .` et `ok .claude-plugin/plugin.json` ; « coût permanent : 0 tokens (seuil 1000) » ; bilan « réussies : 6, échouées : 0, sautées : 2 (skills, agents absents), bloquées : 0 » |

### Les tests discriminent

`PLUGIN_UNDER_TEST=<copie faussée> bash tests/static/test_run_all.sh`, sur deux copies de `run-all.sh` faussées dans `build/mutants/p1/` :

| Copie faussée | Code | Échecs |
| --- | --- | --- |
| une étape bloquée ne fait plus sortir en 2 | 1 | « claude absent : exit 2 » seul |
| un dossier de composants absent est compté réussi | 1 | « skills/ absent : sauté », « agents/ absent : sauté », « skills/ absent : jamais réussi » |

`test_manifest` est prouvé par les copies « manifeste faussé » (`license` Apache-2.0) et « manifeste absent » du même méta-test ; le test du hook Stop, par son rouge sur le hook d'origine (`.sh` non surveillé, script nouveau masqué par son dossier).
