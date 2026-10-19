# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne corrigée, mineure pour un composant ajouté, majeure pour un changement qui casse l'existant.

## [0.1.0] — en cours

Version d'amorçage, construite à la main et jamais publiée : elle reçoit une étiquette locale à la clôture. La 0.1.1 sera la première publication.

### Ajouté

- Manifeste `plugin.json` et marketplace locale `.claude-plugin/marketplace.json`, au modèle de plugin-flutter.
- Suite déterministe `tests/run-all.sh` : manifestes, validation stricte par cible, coût en contexte permanent plafonné à 1 000 tokens ; sorties 0, 1 et 2.
- Base de faits versionnée `scripts/facts/facts.json` : chaque fait porte son énoncé, la version de Claude Code, la date, la source, la façon de le revérifier et son statut ; sondes par la validation stricte ; instantané des formats de `claude plugin init` en 2.1.296.
- Outil `scripts/pp.sh` (`reaudit`, `snapshot`, `diff-snapshots`) et skill `reaudit`, sur demande explicite : faits à revérifier depuis une mise à jour, formats changés, faits que la validation stricte contredit.
- Skill `frame` : cadrage d'un nouveau plugin, une question à la fois avec recommandation motivée, décisions déléguées consignées, PRD et architecture approuvés explicitement (`pp.sh approve`, journal des accords).
- Hook `doc-status-guard` (PostToolUse, fail-open) : un document de cadrage approuvé puis modifié repasse en revue. Installé pour le compte, il tourne dans toutes les sessions, et reste inerte hors d'un projet portant `.plugin-plugin/`.
- Gabarits `templates/PRD.md` et `templates/ARCHITECTURE.md`.
- Point de reprise `.plugin-plugin/checkpoint.md` écrit à chaque étape (`pp.sh checkpoint`), skill `resume` en lecture seule (`pp.sh resume`, dix lignes au plus, incohérences signalées) et hook `checkpoint-reminder` (Stop), qui rappelle une fois un point de reprise périmé.
- Skill `add` (volet skill) et évaluations : `pp.sh check-skill` (analyseur strict d'en-tête), `check-evals` (suite vérifiée sans être lancée), `eval-plan` (sessions, coût, plafond, compte, commande), `eval-run` (rien sans un « oui »), `eval-verdict` (cas réussi par le témoin refusé, Bash sans bwrap bloqué). Suites d'évaluation en JSON, sous-ensemble du YAML.
- Skill `add`, volet hook, et `pp.sh add-hook` : avertissement de portée avant toute écriture, câblage en forme exec, squelette au contrat d'entrée écrit (fail-closed ou fail-open), test d'entrées simulées qui échoue tant que la règle manque, ligne dans `docs/INSTALLATION.md`. `test_paths` contrôle la cohérence du mode et d'`onFailure`, et `shellcheck`.
- Skill `add`, volet agent, et `pp.sh add-agent` / `check-agent` : outils déclarés et connus, jamais `Agent`, relecteur sans écriture, rapport STATUS / FILES_CHANGED / COMMANDS_RUN / OPEN_QUESTIONS ; test de l'agent écrit avant lui ; garde de portée `agent-scope-guard` (PreToolUse, fail-closed) pour un agent qui écrit ou lance Bash. Règles d'en-tête en source unique `tests/headers.sh`, recopiée dans les plugins créés avec `test_headers.sh`.
- Skill `create` et `pp.sh create` : plugin dédié créé depuis un cadrage approuvé — nom vérifié sur GitHub (marketplace `soon`, dépôt `soonlysoul/<nom>`), dossier hors cadrage refusé sans y toucher, charpente du modèle, `git init`, et sa propre suite lancée, verte dès la création.
