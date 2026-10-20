# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne corrigée, mineure pour un composant ajouté, majeure pour un changement qui casse l'existant.

## [à venir] — en cours

### Corrigé

- `pp.sh release` : un hook déclaré en forme shell, son chemin entre guillemets (`bash "${CLAUDE_PLUGIN_ROOT}/hooks/x.sh"`), se lisait `x.sh"`. Passé en forme exec, il comptait pour retiré puis ajouté, et la répétition imposait une majeure. Révélé par la publication de plugin-nixos 0.2.0.

## [0.1.1] — 2026-10-20

Clôture de 0.1.0 : la relecture des sept skills par `plugin-dev:skill-reviewer`, ses constats traités.

### Corrigé

- `pp.sh checkpoint … start` refuse d'effacer le point de reprise inachevé du même skill et nomme l'étape suivante ; `--restart` quand Soon abandonne ce travail. Reprendre un skill relançait son `start`, qui effaçait les étapes faites.
- Un `&` dans la description d'un plugin créé devenait `__DESCRIPTION__` (bash 5.2 et plus) : la charpente rend la description telle quelle.
- `pp.sh add-agent` : un agent qui déclare `Monitor` déclare sa liste blanche et passe sous le garde de portée, comme `Bash`.
- `resume` : test ciblé lancé depuis le dossier du plugin, une consigne pour chaque issue de `pp.sh resume` (sans point de reprise, rien qui reste, publication en cours), blocages et incohérences laissés à la décision de Soon.
- `frame` : reprise lue sur les deux documents, jamais de gabarit sur un document existant, refus du script distingué d'une demande de changement, points « à trancher » listés avant l'accord.
- `create` : point de reprise ouvert après la vérification du cadrage, une consigne par code de sortie, validation stricte lue dans le bilan, `alertes` rapportées.
- `add` : chemins des tests générés (tirets changés en `_`), étapes du point de reprise lues avant de l'ouvrir.
- `check` : un plugin désigné par son nom est cherché à côté du dépôt courant.
- `release` : phrase de déclenchement atteignable sous `disable-model-invocation`, première publication, montage terminé, refus sans ligne de reprise.
- `reaudit` : formats comparés sur un instantané conservé, clone audité, clés exactes de `facts.json`, `non tranché` et « non lancé », un accord par question, étape après le « oui ».

### Ajouté

- `docs/ARCHITECTURE.md`, `docs/INSTALLATION.md`, `docs/USER_GUIDE.md`, `docs/SECURITY.md`, `docs/TROUBLESHOOTING.md` : `check` ne relève plus aucun écart sur plugin-plugin.
- `.plugin-plugin/` de plugin-plugin lui-même : approbations du plan et de l'architecture consignées.

Coût en contexte permanent : ~880 tokens — release ~130, create ~100, check ~140, resume ~110, add ~170, frame ~130, reaudit ~100.

## [0.1.0] — 2026-10-20

Version d'amorçage, construite à la main et jamais publiée : étiquette locale `plugin-plugin--v0.1.0`, posée sur la fin de la phase 15. La 0.1.1 est la première publication.

### Ajouté

- Manifeste `plugin.json` et marketplace locale `.claude-plugin/marketplace.json`, au modèle de plugin-flutter.
- Suite déterministe `tests/run-all.sh` : manifestes, validation stricte par cible, coût en contexte permanent plafonné à 1 000 tokens ; sorties 0, 1 et 2.
- Base de faits versionnée `scripts/facts/facts.json` : chaque fait porte son énoncé, la version de Claude Code, la date, la source, la façon de le revérifier et son statut ; sondes par la validation stricte ; instantané des formats de `claude plugin init` en 2.1.296.
- Outil `scripts/pp.sh` (`reaudit`, `snapshot`, `diff-snapshots`) et skill `reaudit`, sur demande explicite : faits à revérifier depuis une mise à jour, formats changés, faits que la validation stricte contredit.
- Skill `frame` : cadrage d'un nouveau plugin, dans un dossier vide ou encore absent (créé par `pp.sh init-state`), une question à la fois avec recommandation motivée, décisions déléguées consignées, PRD et architecture approuvés explicitement (`pp.sh approve`, journal des accords).
- Hook `doc-status-guard` (PostToolUse, fail-open) : un document de cadrage approuvé puis modifié repasse en revue. Installé pour le compte, il tourne dans toutes les sessions, et reste inerte hors d'un projet portant `.plugin-plugin/`.
- Gabarits `templates/PRD.md` et `templates/ARCHITECTURE.md`.
- Point de reprise `.plugin-plugin/checkpoint.md` écrit à chaque étape (`pp.sh checkpoint`), skill `resume` en lecture seule (`pp.sh resume`, dix lignes au plus, incohérences signalées) et hook `checkpoint-reminder` (Stop), qui rappelle une fois un point de reprise périmé.
- Skill `add` (volet skill) et évaluations : `pp.sh check-skill` (analyseur strict d'en-tête), `check-evals` (suite vérifiée sans être lancée), `eval-plan` (sessions, coût, plafond, compte, commande), `eval-run` (rien sans un « oui »), `eval-verdict` (cas réussi par le témoin refusé, Bash sans bwrap bloqué). Suites d'évaluation en JSON, sous-ensemble du YAML.
- Skill `add`, volet hook, et `pp.sh add-hook` : avertissement de portée avant toute écriture, câblage en forme exec, squelette au contrat d'entrée écrit (fail-closed ou fail-open), test d'entrées simulées qui échoue tant que la règle manque, ligne dans `docs/INSTALLATION.md`. `test_paths` contrôle la cohérence du mode et d'`onFailure`, et `shellcheck`.
- Skill `add`, volet agent, et `pp.sh add-agent` / `check-agent` : outils déclarés et connus, jamais `Agent`, relecteur sans écriture, rapport STATUS / FILES_CHANGED / COMMANDS_RUN / OPEN_QUESTIONS ; test de l'agent écrit avant lui ; garde de portée `agent-scope-guard` (PreToolUse, fail-closed) pour un agent qui écrit ou lance Bash. Règles d'en-tête en source unique `tests/headers.sh`, recopiée dans les plugins créés avec `test_headers.sh`.
- Skill `add`, volet MCP, et `pp.sh add-mcp` : déclaration d'un serveur existant dans `.mcp.json` — local par un lanceur bash de `scripts/`, cité par `${CLAUDE_PLUGIN_ROOT}`, ou distant en HTTPS ou WSS —, valeurs de l'utilisateur en `${VAR}`, aucun secret en clair, aucune installation impérative, ni dans la déclaration ni dans le lanceur ; test du serveur écrit avant lui ; variables et doublure `evals/mocks/<serveur>/` documentées dans le README. Règles en source unique `tests/mcp.sh`, appliquées par `test_paths` à tout plugin du modèle. `pp.sh out-of-scope` refuse le code d'un serveur MCP, les channels, les serveurs de langage, les styles de sortie, les commandes classiques, les options de plugin et les dépendances entre plugins, chacun avec sa raison et son déclencheur.
- Skill `release`, sur demande explicite, et `pp.sh release` : répétition de publication qui n'envoie rien. Refus sur un arbre non enregistré, une validation stricte ou une suite rouge, une autre branche que `main`, un plugin hors de la racine de son dépôt, un `origin` étranger, rien depuis la dernière étiquette ; marketplace et dépôt lus sur GitHub par `gh api` ; version proposée selon la nature du changement (composant retiré : majeure, ajouté : mineure, sinon correctif ; `--bump` plus fort seulement) ; entrée du CHANGELOG rédigée, suite et étiquette (`claude plugin tag --dry-run`) éprouvées sur une copie jetable ; coût en contexte par composant, alerte au-delà de 1 000 tokens ; chaque geste listé avec sa commande exacte ; commande d'installation ou de mise à jour. Gestes locaux `pp.sh release-write` (version et CHANGELOG) et `pp.sh marketplace-entry` (entrée de la marketplace `soon`).
- Publication sous accord, `pp.sh publish` et `pp.sh mount` : le plan prouvé par la répétition est figé, puis annoncé étape par étape — les gestes locaux jusqu'à un geste GitHub —, chacune avec ses commandes exactes et lancée seulement par la commande annoncée, après un « oui » tapé. Hook `consent-capture` (UserPromptSubmit, fail-open) : le « oui » littéral est consigné, toute autre réponse ou trente minutes de silence retirent l'annonce. Hook `gesture-guard` (PreToolUse, fail-closed) : un geste GitHub ne passe qu'une fois, annoncé et accordé ; suppression de dépôt, push forcé, réécriture d'historique, push sur `main` de la marketplace et fusion refusés ; le journal des accords ne s'écrit par aucun outil. Ce qui est fait se lit dans les dépôts : une reprise après une coupure ne refait rien ; chaque geste est journalisé (fait, échoué, refusé, déjà fait, commande qui reprend). La marketplace change par une branche et une PR, jamais sur `main`. `pp.sh resume` signale une publication en cours.
- Skill `check` et `pp.sh check` : les écarts d'un plugin au modèle de plugin-flutter, un par ligne avec sa catégorie, sans rien modifier — manifestes, fichiers à la racine, arborescence (hooks sous `hooks/scripts/`), forme exec des hooks, `timeout` et `onFailure`, en-têtes de skills et d'agents, garde de portée, chemins cités, serveurs MCP, harnais de tests, fichiers parasites, identifiants en clair (ligne seule, jamais l'identifiant). Seuls comptent les fichiers qu'un clone porterait. `add-hook`, `add-agent` et `add-mcp` refusent un plugin qui a des écarts.
- Ajout à un plugin du modèle que plugin-plugin n'a pas créé (plugin-flutter) : le diff ne touche que le composant et son câblage, sans modifier une ligne existante ; tests générés lancés par le harnais du plugin, `tests/headers.sh` posé s'il manque ; un agent qui écrit est refusé quand le plugin a son propre garde de portée ; aucun point de reprise, la suite d'origine comparée avant et après.
- `pp.sh rebuild` : reconstruit un plugin existant dans un dossier à part — charpente de plugin-plugin, contenu du dernier commit importé tel quel —, rapporte les écarts de charpente, lance la suite de la reconstruction et prouve l'original intact. plugin-flutter reconstruit : aucun écart, sa suite à 100 %, validation stricte sur chaque cible.
- Réécriture de plugin-nixos au modèle, `tests/rewrite/plugin-nixos.sh`, un test de plugin-plugin jamais publié : `rebuild`, puis la forme exec des hooks, l'arborescence `hooks/scripts/` et le harnais du modèle ; suite portée verte, `check` à zéro écart, chaque cas de la suite d'origine gardé, original intact (`test_rewrite_nixos`).
- Coût en contexte : au-delà de 1 000 tokens, la suite de plugin-plugin échoue, celle d'un plugin produit alerte et reste verte (`OVER_BUDGET`, ligne « alertes » du bilan), comme la répétition de publication ; le séparateur de milliers de `claude plugin details` (« ~1,126 tok ») est lu.
- `rebuild` garde les descriptions de la marketplace locale de l'original.
- Un outil sans extension sous `scripts/` (le `nixconf` de plugin-nixos) a les contrôles de tout script — `bash -n`, `shellcheck`, `#!/usr/bin/env bash`, cité par `${CLAUDE_PLUGIN_ROOT}` —, dans `test_paths` comme dans `check`.
- Harnais du modèle : `tests/lib.sh` porte `SCRIPTS`, `bash_input` et `restricted_path`, dont se servent les tests de hooks de plugin-flutter ; le `.gitignore` des plugins créés ignore `tests/.tmp/` ; `test_run_all` contrôle le bilan de `run-all.sh`, plus les messages d'un autre test, et s'arrête avant toute copie s'il n'est pas pointé sur un plugin.
- Évaluations : un cas qui restreint Bash par un motif (`Bash(bash:*)`) ne reçoit que ce motif dans `--allow-tools`, jamais Bash entier.
- Skill `create` et `pp.sh create` : plugin dédié créé depuis un cadrage approuvé — nom vérifié sur GitHub (marketplace `soon`, dépôt `soonlysoul/<nom>`), dossier hors cadrage refusé sans y toucher, charpente du modèle, `git init`, et sa propre suite lancée, verte dès la création.
