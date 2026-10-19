# PROGRESS — plugin-plugin v0.1

Dernière mise à jour : 2026-10-19
Reprise : lire ce fichier, puis `git log --oneline` ; le plan fait foi (`docs/PLAN.md`, APPROUVÉ).

## État courant

Branche de travail `feat/v0.1.0`. **Phases 1 à 5 terminées** : plugin-plugin 0.1.0 chargeable, base de faits de 102 faits, ré-audit à zéro sur 2.1.296, cadrage (`frame`), garde de statut des documents, création d'un plugin vert (`create`), reprise depuis le disque (`resume`, rappel du point de reprise), suite déterministe verte, coût permanent 546 tokens. **Phase 6 faite, sauf son passage réel**, payant, qui attend l'accord de Soon (voir « Phase 6 — En attente »). Les phases 7, 8, 9, 11 et 12 n'en dépendent pas et se poursuivent : **phase 7 terminée**.

**À trancher par Soon** — le plan approuvé affirme, dans « Tests et validation », que `claude plugin validate .` ne valide que la marketplace. Mesuré en phase 2 : c'est faux sur 2.1.296 (voir ci-dessous). Rien ne casse — la suite valide toujours chaque cible —, mais la phrase du plan est à corriger, ce qui le repasse en revue. Le plan n'a pas été modifié.

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

## Phase 2 — Base de faits et ré-audit — terminée

- [x] Import initial : 98 faits dans `scripts/facts/facts.json` (83 confirmés, 3 infirmés, 12 à vérifier) — phase A de plugin-flutter, ses constats des phases B à F, les faits du 2026-10-19, les affirmations de plugin-dev « à vérifier » (dont `when_to_use` « déprécié » et le redémarrage pour les hooks, qui contredisent la phase A), les deux limites de description (1 536 doc, 1 024 plugin-nixos).
- [x] Version inchangée (doublure 2.1.296) : « rien à revérifier depuis la version 2.1.296 », listes vides, aucun instantané produit.
- [x] Version plus récente (doublure 2.1.297) : les faits mesurés sur 2.1.296 sont listés, avec leur façon de revérifier ; un fait mesuré sur 2.1.297 ne l'est pas.
- [x] Instantané réel `scripts/facts/snapshots/2.1.296.json`, produit par `pp.sh snapshot` sous un HOME jetable ; deux instantanés qui diffèrent d'un fichier listent ce format comme changé.
- [x] Un fait contredit par la validation stricte est signalé « à corriger » — sur la doublure, puis sur un **vrai fait** (ci-dessous).
- [x] Skill `reaudit` (`disable-model-invocation`) et sa suite d'évaluation `evals/reaudit/` (un cas positif, un négatif, trois exécutions), écrite, non lancée : elle exige Bash, donc bwrap (décision c).

Outil : `scripts/pp.sh` (`reaudit`, `snapshot`, `diff-snapshots`), sans session ni quota.

### Sondes

| Sonde | Commande | Résultat |
| --- | --- | --- |
| `plugin init` sous HOME jetable | `HOME=<tmp> CLAUDE_CONFIG_DIR=<tmp>/.claude claude plugin init sonde-formats --with skills agents hooks mcp lsp output-style channel --author Soon --author-email sonde@example.invalid` | exit 0 ; écrit sous `$CLAUDE_CONFIG_DIR/skills/sonde-formats/` ; deux générations identiques (`diff -r`) |
| Empreinte de `~/.claude/skills` autour de `pp.sh snapshot` | `find ~/.claude/skills -type f … \| sha256sum` | `81b73bb5b44fe04e` avant et après |
| Gabarit d'évaluation | `claude plugin eval init --bare essai` (dossier jetable) | exit 0, sans session : `evals/essai/prompt.md` et `graders/criteria.md`, pas de `case.yaml` |
| Le validateur lit-il `evals/` ? | `claude plugin validate evals --strict` ; `… evals/a/case.yaml --strict` | exit 1 « No manifest found » ; exit 1 « Invalid JSON syntax » : il n'inspecte pas les cas |
| `schema_version` des cas | doc plugin-evals du 2026-10-19 ; binaire 2.1.296 | la doc exige `"1.1"`, le binaire cite `(e.g. "1.0")` : **à vérifier** au premier passage réel ; les suites gardent `"1.0"` du plan |
| Racine portant les deux manifestes | `claude plugin validate . --strict --json`, `plugin.json` avec un champ `bogus` | **exit 1**, avertissement « Unknown field 'bogus' » sur `plugin.json` |
| Composants vus depuis la racine | même commande, `hooks.json` tronqué et un `SKILL.md` sans en-tête | exit 1 : les deux fichiers sont signalés, depuis `.` comme depuis `plugin.json` |
| Angles morts du validateur | `validate agents --strict` (`description: [unclosed`) ; `validate .claude-plugin/plugin.json --strict` (script de hook absent) | exit 0 dans les deux cas |
| `disable-model-invocation` et coût | `claude --plugin-dir <copie> plugin details plugin-plugin`, avec puis sans la ligne | ~227 tokens dans les deux cas |
| Catalogue local | `~/.claude/plugins/marketplaces/soon` contre `gh api repos/soonlysoul/claude-plugins/contents/…` | local : `flutter-forge` ; GitHub : `plugin-flutter`, `plugin-nixos` |

Conséquences :

- **La validation de la racine couvre le plugin.** `contents: []` veut dire « aucun constat », pas « non inspecté » : la conclusion de plugin-flutter (phase B) venait d'un `plugin.json` sans défaut. La suite garde ses quatre cibles, redondantes mais sans coût.
- **`disable-model-invocation` ne protège pas le budget tel qu'il est mesuré.** Les en-têtes des skills sur demande explicite restent donc courts : `reaudit` est passé de ~227 à ~115 tokens.

### La validation stricte l'emporte, sur un vrai fait

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| Import | fait `validate-root-marketplace-only` repris de plugin-flutter, `confirmé`, sonde attendue en réussite | | |
| Ré-audit réel | `bash scripts/pp.sh reaudit` | 0 | « faits à corriger (la validation stricte l'emporte) : 1 — validate-root-marketplace-only : la validation stricte échoue sur root-marketplace-only/., le fait attend une réussite » |
| Correction | le fait passe `infirmé` ; nouveau fait `validate-root-covers-plugin`, `confirmé` | | |
| Ré-audit réel | `bash scripts/pp.sh reaudit` | 0 | « rien à revérifier depuis la version 2.1.296 », « faits à corriger … : 0 », « à vérifier, jamais tranchés : 12 » |

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/static/test_facts.sh` | 1 | « base de faits présente » : absente |
| ROUGE | `bash tests/static/test_reaudit.sh` | 1 | « scripts/pp.sh présent » : absent |
| ROUGE | `bash tests/static/test_paths.sh` | 1 | « skills et agents trouvés » : aucun |
| ROUGE | `bash tests/static/test_reaudit.sh` (outil écrit) | 1 | 29 réussis, 5 échoués : `jq` de `print_diff` (« Cannot check whether object has a object key »), et base réelle absente — défaut corrigé |
| VERT | `bash tests/run-all.sh` | 0 | `test_facts : 49`, `test_reaudit : 34`, `test_paths : 7`, `test_run_all : 21` réussis ; validation `ok .`, `ok .claude-plugin/plugin.json`, `ok skills` ; « coût permanent : 115 tokens (seuil 1000) » ; bilan « réussies : 10, échouées : 0, sautées : 1 (agents), bloquées : 0 » |

### Les tests discriminent

Copies faussées dans `build/mutants/p2/`, lancées par `PLUGIN_UNDER_TEST=<copie>` :

| Copie faussée | Suite | Échecs |
| --- | --- | --- |
| une version égale compte comme plus ancienne | test_reaudit | 9, dont « version inchangée : le message dit rien à revérifier » |
| les sondes sont ignorées | test_reaudit | 2 : « sonde contredite : le fait est compté à corriger », « … est nommé » |
| `plugin init` sous le vrai HOME | test_reaudit | 1 : « snapshot : HOME et CLAUDE_CONFIG_DIR jetables, jamais ~/.claude » |
| un fait retiré, un statut « ok » | test_facts | 2 |
| un chemin cité absent | test_paths | 1 |

## Phase 3 — Cadrage — terminée

- [x] `frame` pose une question à la fois, chacune avec une recommandation motivée ; une décision déléguée est consignée par `pp.sh delegate` : date, question, choix, raison, « révisable » (US-1, US-2).
- [x] Le nom passe par `pp.sh check-name` : chaque refus nomme la règle (majuscules, soulignés, caractère hors kebab-case, préfixe `plugin-` absent, domaine vide) ; la langue des identifiants est demandée, anglais recommandé.
- [x] Seul un message explicite d'approbation passe un document en `APPROUVÉ`, avec la date et la citation exacte, et l'empreinte du document au journal `.plugin-plugin/approvals.log` ; « ok », « oui mais … », « d'accord », un message vide laissent document et journal identiques octet pour octet (US-3).
- [x] Hook `doc-status-guard` (PostToolUse, `Edit|Write`, fail-open) : un document approuvé dont l'empreinte ne correspond plus au journal repasse en `REVUE` et Claude en est prévenu ; une approbation écrite à la main, sans trace au journal, aussi ; brouillon et revue gardent leur statut ; hors d'un projet géré, ou hors de `docs/`, il est silencieux (US-4).
- [x] Gabarits `templates/PRD.md` et `templates/ARCHITECTURE.md`, nés en `BROUILLON`.
- [x] Suite d'évaluation `evals/frame/` : deux cas positifs, un négatif, trois exécutions chacun. Écrite, non lancée.

Mécanisme retenu : le statut vit dans la ligne `**Statut : BROUILLON|REVUE|APPROUVÉ**` du document ; l'approbation, dans le journal des accords, avec l'empreinte du document hors cette ligne. Le hook compare les deux : il distingue ainsi l'écriture de l'approbation elle-même d'une modification après coup, sans état préalable. Limite connue : une modification faite par Bash (`sed -i`) n'est pas vue avant la prochaine écriture par `Edit` ou `Write`.

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/hooks/test_doc_status_guard.sh` | 1 | « hooks/scripts/doc-status-guard.sh présent » : absent |
| ROUGE | `bash tests/static/test_frame.sh` | 1 | `init-state`, `check-name`, `delegate`, `approve` inconnus, gabarits absents |
| VERT | `bash tests/run-all.sh` | 0 | `test_doc_status_guard : 20`, `test_frame : 40`, `test_paths : 26` réussis ; « coût permanent : 255 tokens (seuil 1000) » ; bilan « réussies : 12, échouées : 0, sautées : 1 (agents), bloquées : 0 » |

### Les tests discriminent

Copies faussées dans `build/mutants/p3/` :

| Copie faussée | Suite | Échecs |
| --- | --- | --- |
| le hook ne compare plus l'empreinte | test_doc_status_guard | 2, dont « écriture de l'approbation : le statut reste approuvé » |
| le hook ignore `.plugin-plugin/` | test_doc_status_guard | 2 : « projet non géré : silencieux », « … fichier intact » |
| `approve` accepte tout message | test_frame | 10 : chaque refus, et l'identité du document et du journal |
| `check-name` sans règle de préfixe | test_frame | 2 : `flutter-forge`, `plugin` |
| `timeout` retiré de `hooks.json` | test_paths | 2 : « timeout déclaré », « câblé : … timeout=10 » |

## Phase 4 — Créer un plugin vert — terminée

- [x] Refus qui nomment la règle : majuscules, soulignés, préfixe `plugin-` absent (`flutter-forge`), domaine vide (US-5).
- [x] Refus qui nomment l'endroit : nom présent dans la marketplace `soon`, lue sur GitHub par `gh api … -H "Accept: application/vnd.github.raw+json"` (doublure en test), ou dépôt `soonlysoul/<nom>` existant ; GitHub illisible ou `gh` absent : « bloqué », exit 2 (US-5, US-28).
- [x] Dossier contenant un fichier hors cadrage, cadrage en brouillon, approbation écrite à la main sans trace au journal, dossier inexistant : refus, dossier identique octet pour octet, prouvé par empreinte de l'arborescence (US-7, US-3).
- [x] Plugin créé : sa propre suite sort en 0 et la validation stricte passe sur `.` et `.claude-plugin/plugin.json`, sans aucune retouche (US-6, critère 1). `create` lance cette suite lui-même et en donne le code de sortie.
- [x] Manifeste sans e-mail ; aucun chemin personnel ni du store dans ce qui est produit ; cadrage approuvé laissé intact ; `git init -b main`.
- [x] Suite d'évaluation `evals/create/` : deux cas positifs (cadrage approuvé, cadrage en brouillon), un négatif, trois exécutions chacun ; les cadrages d'essai sont posés par `setup.sh`, dont l'empreinte a été vérifiée conforme à `pp.sh`. Écrite, non lancée : elle exige Bash et `--scaffold`.

Le plugin créé reçoit le harnais de plugin-plugin lui-même — `tests/lib.sh`, `run-all.sh`, `static/test_paths.sh`, `static/test_run_all.sh`, et `static/test_manifest.sh` avec son nom — : une seule source de vérité, et le critère 1 éprouve ce harnais à chaque passage. Les attentes propres à plugin-plugin sont passées de `test_paths.sh` à `test_components.sh`, qui n'est pas copié.

Budget : trois skills coûtaient 405 tokens permanents ; en-têtes resserrés, 312 (environ 105 par skill). Sept skills tiendraient vers 730.

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/static/test_create.sh` | 1 | 39 échecs : `create` inconnu |
| ROUGE | `bash tests/static/test_create.sh` (outil écrit) | 1 | 54 réussis, 1 échoué : « aucun chemin personnel ni du store dans ce qui est produit » — le motif de recherche de `test_paths.sh`, copié dans le plugin créé, contenait lui-même `/home/` ; motif réécrit `'/(home\|Users)/\|/nix/(store)/'` |
| ROUGE | `bash tests/run-all.sh` | 1 | `test_run_all : 17 réussis, 4 échoués` : la copie du méta-test retirait `test_run_all.sh`, que `create` doit recopier ; la copie retire désormais aussi `test_create.sh`, étranger à `run-all.sh` et lent |
| ROUGE | `bash tests/static/test_run_all.sh` (cas ajouté) | 1 | « PLUGIN_UNDER_TEST hérité : la suite vérifie quand même son propre dossier » : la variable fuyait dans la suite lancée par `create`, qui vérifiait alors un autre dossier ; `run-all.sh` l'ignore désormais |
| VERT | `bash tests/run-all.sh` | 0 | `test_create : 57`, `test_components : 5`, `test_run_all : 22` réussis ; « coût permanent : 312 tokens (seuil 1000) » ; bilan « réussies : 14, échouées : 0, sautées : 1 (agents), bloquées : 0 » |

### Les tests discriminent

Copies faussées de `scripts/pp.sh` dans `build/mutants/p4/`, une ligne changée chacune, `PLUGIN_UNDER_TEST=<copie> bash tests/static/test_create.sh` :

| Copie faussée | Premiers échecs |
| --- | --- |
| la marketplace n'est plus consultée | « dans la marketplace soon : refusé, raison nommée », « … dossier identique » |
| les fichiers hors cadrage sont acceptés | « fichier hors cadrage : refusé, raison nommée », « … dossier identique » |
| l'empreinte d'approbation n'est plus comparée | « approbation écrite à la main : refusé, raison nommée », « … dossier identique » |
| le nom n'est plus reporté dans `test_manifest.sh` | « create : exit 0 », « create lance la suite du plugin créé, qui passe » |
| toute erreur de `gh` vaut 404 | d'abord **non pris** : la doublure faisait échouer tous les appels, la recherche du dépôt n'était jamais atteinte. Cas « dépôt illisible, marketplace lisible » ajouté ; rejoué : « dépôt illisible, marketplace lisible : refusé, raison nommée » |

## Phase 5 — Reprise depuis le disque — terminée

- [x] `pp.sh checkpoint <dossier> start|done|block` écrit `.plugin-plugin/checkpoint.md` : skill, branche, dernier commit, étapes à faire et faites (commande, code de sortie), test ciblé, blocages. Une étape inconnue ou sans code de sortie est refusée. `frame` et `create` l'appellent à chaque étape.
- [x] Création interrompue (simulée) : `pp.sh resume` dit ce qui est fait et ce qui reste, en dix lignes au plus, et propose l'étape 4 sans refaire les précédentes (US-34).
- [x] Incohérences signalées sur une seule ligne : commit plus récent que le point de reprise, autre branche, fichiers modifiés non commités (le dossier d'état mis à part).
- [x] Aucune écriture avant l'accord : `resume` est en lecture seule, prouvé par l'empreinte de l'arborescence, `.git` compris ; `git --no-optional-locks status` évite même la réécriture de l'index.
- [x] Hook `checkpoint-reminder` (Stop) : silencieux sans dossier d'état, sans point de reprise, si `stop_hook_active`, ou si seul `.plugin-plugin/` a changé ; un seul rappel si le point est plus ancien que le dernier commit ou qu'un fichier modifié.
- [x] Suite d'évaluation `evals/resume/` : une création interrompue (posée par `setup.sh`, lue correctement par `pp.sh resume`) et un cas négatif. Écrite, non lancée.

**Décision : `.plugin-plugin/` est versionné, sauf le point de reprise.** Le journal des accords et les décisions déléguées sont des preuves : `doc-status-guard` et `create` comparent l'empreinte d'un document à ce journal, et le perdre ferait repasser tout le cadrage en revue. Le point de reprise, lui, change à chaque étape : versionné, il salirait l'arbre en permanence, alors que la publication refuse un arbre sale (US-23). Un plugin créé ignore donc `.plugin-plugin/checkpoint.md` (`scripts/scaffold/gitignore`). Le journal des gestes de publication se tranchera en phase 12.

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/static/test_resume.sh` | 1 | 24 échecs : `checkpoint` et `resume` inconnus |
| ROUGE | `bash tests/hooks/test_checkpoint_reminder.sh` | 1 | « hooks/scripts/checkpoint-reminder.sh présent » : absent |
| VERT | `bash tests/run-all.sh` | 0 | `test_resume : 31`, `test_checkpoint_reminder : 12`, `test_components : 7` réussis ; « coût permanent : 418 tokens (seuil 1000) » ; bilan « réussies : 16, échouées : 0, sautées : 1 (agents), bloquées : 0 » |

### Les tests discriminent

Copies faussées dans `build/mutants/p5/`, une ligne changée chacune :

| Copie faussée | Suite | Premier échec |
| --- | --- | --- |
| la branche n'est plus comparée | test_resume | « autre branche » |
| le dossier d'état compte comme modifié | test_resume | « le point de reprise lui-même n'est pas compté comme modifié » |
| le code de sortie devient facultatif | test_resume | « étape sans code de sortie : refusé » |
| le rappel ignore `stop_hook_active` | test_checkpoint_reminder | « stop_hook_active : silencieux, un seul rappel » |
| le rappel ne met plus `.plugin-plugin/` à part | test_checkpoint_reminder | « seul .plugin-plugin/ a changé : silencieux » |

## Phase 6 — Ajouter un skill avec son évaluation — faite, sauf le passage réel

- [x] `pp.sh check-evals <plugin> <skill>` vérifie une suite sans la lancer : `case.yaml` écrit en JSON (sous-ensemble du YAML, lu par `jq` sans autre dépendance), `schema_version` `"1.0"`, nom préfixé par le skill, `runs` ≥ 3 déclaré, `execution.prompt`, au moins un correcteur de résultat par cas (pas une regex sur la trace), au moins un cas positif et un cas négatif par suite, un négatif en `min: 0`, `max: 0`, `arm: both`. Chaque règle manquante produit un refus qui la nomme (US-10). Les suites des phases 2 à 5, converties en JSON, la passent.
- [x] `pp.sh check-skill` : analyseur strict d'en-tête repris de plugin-flutter (sept formes cassées refusées), forme du modèle (`Use when …`, `not for …`, phrase française citée), `allowed-tools` refusé, 1 536 caractères au plus, moins de 500 lignes, aucun `$0`–`$9`. Il a trouvé un vrai écart : la description de `resume` disait « Use to », corrigée.
- [x] `pp.sh eval-plan` annonce le nombre de sessions, la fourchette de coût (0,13 à 0,23 USD par session, mesuré), le plafond (3 USD par défaut, `--max-cost` avant l'annonce), le compte qui paie, et la commande exacte ; `pp.sh eval-run` ne lance rien sans un « oui » littéral — « ok », « oui mais … », « d'accord », un message vide sont refusés et la doublure de `claude` n'est jamais appelée (US-11).
- [x] La commande porte toujours `--no-publish`, `--max-cost-usd` et `--output-dir` sous `evals/results/` (ignoré par git), jamais `--trust-plugin` ; `--allow-tools Bash` seulement pour un cas qui l'exige ; `--ablation none` pour un passage à un bras (`--one-arm`).
- [x] `pp.sh eval-verdict` : un cas positif que le témoin réussit est refusé (US-9) ; un cas qui exige Bash sans bwrap ni socat est « bloqué : bwrap absent », jamais réussi (US-12) ; une erreur de bac à sable, « bloqué » ; un passage partiel, « partiel ».
- [x] Skill `add` (volet skill, détails dans `skills/add/reference/skill.md`).
- [x] Sonde : confiance hors terminal interactif (ci-dessous).
- [ ] Sonde : compte annoncé par `claude auth status`, comparé au titulaire réel — **en attente**.
- [ ] Sonde : autres plugins installés chargés dans le bras témoin — **en attente du passage réel** (`--keep-temp`).
- [ ] Premier passage réel, sur accord : rouge avant le skill, vert avec Δ > 0 (critères 4, 5) — **en attente de l'accord de Soon**.

### Sondes

| Sonde | Commande | Résultat |
| --- | --- | --- |
| Confiance hors terminal | `claude plugin eval build/temoin-p6/plugin-codenames --case 'aucun-*' --no-publish --max-cost-usd 0.01 --ablation none --runs 1 </dev/null` | exit 1, avant tout chargement : « is not a trusted plugin directory, and this run cannot stop to ask you about it (no interactive terminal …) ». Aucune session, aucun coût. `eval-run` le dit désormais « bloqué », avec la commande gratuite qui approuve le dossier. |
| Compte qui paie | `claude auth status --json` | Pour `~/.claude`, il annonce le compte pro (abonnement `pro`), alors que le CLAUDE.md du poste attribue `~/.claude` au compte ordinaire. Ce bloc peut ne pas dire le titulaire du jeton ; seul `/api/oauth/profile` tranche, avec le jeton du profil : non fait, geste sensible laissé à Soon. L'adresse n'est pas recopiée ici : ce dépôt sera public. |
| Isolement du bras témoin | doc plugin-evals, « How runs are isolated » | La doc dit qu'aucun autre plugin installé n'est chargé dans une exécution : l'hypothèse du PRD (flutter-forge chargé dans le témoin) serait fausse. À confirmer par les traces du passage réel (`--keep-temp`). |

### Témoin du premier passage réel

`build/temoin-p6/plugin-codenames`, créé par `pp.sh create` — suite du plugin créé : exit 0. Son cadrage a été approuvé par un accord **de fixture** (« oui » écrit par le test, non par Soon) : ce dossier, ignoré par git, n'est jamais publié. Skill `codename`, encore absent : il donnera des noms de code inventés (Atlas → Héron-7, Borée → Lynx-3), que le modèle ne peut pas connaître sans lui, et s'évalue donc sans Bash. Suite : `conforme : 3 cas (2 positifs, 1 négatif), 3 exécutions par cas au moins`.

### Rouge puis vert (partie sans quota)

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/static/test_frontmatter.sh` (bibliothèque mise de côté) | 1 | 18 échecs, dont « scripts/lib/frontmatter.sh présent » |
| ROUGE | `bash tests/static/test_evals.sh` | 1 | 45 échecs : commandes inconnues |
| ROUGE | `bash tests/static/test_evals.sh` (cas ajoutés) | 1 | « un seul bras : … » (2), puis « dossier non approuvé : … » (2) |
| VERT | `bash tests/run-all.sh` | 0 | `test_evals : 61`, `test_frontmatter : 26` réussis ; « coût permanent : 535 tokens (seuil 1000) » ; bilan « réussies : 18, échouées : 0, sautées : 1, bloquées : 0 » |

### Les tests discriminent

| Copie faussée (une ligne) | Suite | Premier échec |
| --- | --- | --- |
| plus de règle « au moins un cas négatif » | test_evals | « aucun cas négatif : refusé, règle nommée » |
| `--trust-plugin` ajouté à la commande | test_evals | « jamais --trust-plugin » |
| tout message vaut accord | test_evals | « « ok » : refusé », « « ok » : rien n'est lancé » |
| un positif réussi par le témoin est accepté | test_evals | « positif réussi par le témoin : refusé » |
| Bash n'est plus détecté | test_evals | « Bash sans bwrap ni socat : exit 2 » |
| `allowed-tools` accepté | test_frontmatter | « allowed-tools : refusé, règle nommée » |

### Phase 6 — En attente

Le passage réel exige trois gestes de Soon, dans cet ordre :

1. **Approuver le dossier du témoin, sans coût**, une fois, dans un terminal :
   `cd build/temoin-p6/plugin-codenames && claude plugin eval . --case 'aucun-*' --no-publish --max-cost-usd 0.01 --ablation none --runs 1`, puis répondre `y`.
2. **Rouge** — un « oui » à cette annonce : 9 sessions (3 cas × 3 exécutions × 1 bras), 1,17 à 2,07 USD, plafond 3 USD, compte annoncé : le compte pro de `~/.claude` (voir la sonde).
3. **Vert**, après l'écriture du skill — un « oui » à cette annonce : 18 sessions (3 cas × 3 exécutions × 2 bras), 2,34 à 4,14 USD, plafond proposé 4,5 USD.

## Phase 7 — Ajouter un hook testé sans session — terminée

- [x] `pp.sh add-hook <plugin> --name --event [--matcher] --mode [--timeout] [--dry-run]` câble `hooks/hooks.json` en forme exec, par `${CLAUDE_PLUGIN_ROOT}`, `timeout` déclaré, `onFailure` `block` en fail-closed, `continue` en fail-open, aucun sur `Stop` ; le script existe.
- [x] Refus nommés, plugin intact : nom hors kebab-case, événement inconnu, filtre absent sur un événement d'outil, filtre sur `Stop`, fail-closed sur `PostToolUse` (« ne peut pas bloquer ») ou sur `Stop`, mode inconnu, hook déjà présent, dossier hors modèle.
- [x] Script produit : `#!/usr/bin/env bash`, mode déclaré en tête (`# Fail-closed` ou `# Fail-open`), variables entre guillemets, raison sur stderr, exit 2 pour bloquer ; en fail-closed, blocage sur entrée illisible et sur `jq` absent ; `shellcheck -S warning` passe.
- [x] Le test d'entrées simulées échoue sur le squelette pour la bonne raison (« règle de garde-rm : à écrire »), le contrat d'entrée passant déjà ; puis, la règle et ses cas écrits, la suite du plugin passe (US-14, critère 4).
- [x] L'avertissement de portée est la première ligne de `add-hook`, `--dry-run` compris, qui n'écrit rien ; il figure dans `docs/INSTALLATION.md` du plugin, section « Portée des hooks » (US-15).
- [x] Inerte hors de son contexte, sans ordre supposé entre hooks : consignes de `skills/add/reference/hook.md`, et cas « hors contexte » exigé dans le test de la règle.
- [x] `test_paths` générique contrôle désormais, pour tout plugin du modèle, la cohérence du mode déclaré et d'`onFailure`, et `shellcheck -S warning` sur chaque script (sauté sans `shellcheck`).

Les tests qui créent un plugin (`test_create`, `test_add_hook`) sont rangés dans `tests/integration/` : ils ont besoin de `claude`, et les copies du méta-test `test_run_all`, qui n'éprouvent que `run-all.sh`, les retirent d'un bloc.

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/static/test_add_hook.sh` | 1 | 29 échecs : `add-hook` inconnu |
| VERT | `bash tests/integration/test_add_hook.sh` | 0 | 35 réussis, dont « suite du plugin : rouge (exit 1) », « rouge pour la bonne raison : la règle n'est pas écrite », puis « règle écrite : suite du plugin verte (exit 0) » |
| ROUGE | `bash tests/run-all.sh` | 1 | « claude absent : exit 2 » : la copie du méta-test lançait `test_add_hook`, qui crée un plugin ; tests d'intégration déplacés |
| VERT | `bash tests/run-all.sh` | 0 | 19 étapes réussies ; « coût permanent : 546 tokens (seuil 1000) » ; « échouées : 0, sautées : 1, bloquées : 0 » |

### Les tests discriminent

| Copie faussée (une ligne de `pp.sh`) | Premier échec de `test_add_hook` |
| --- | --- |
| `--dry-run` écrit | « --dry-run n'écrit rien » |
| fail-closed accepté sur `PostToolUse` | « fail-closed sur PostToolUse : refusé, raison nommée » |
| squelette fail-closed qui laisse passer une entrée illisible | « squelette fail-closed : entrée illisible bloquée » |
| `onFailure` toujours `continue` | « hooks.json : … onFailure block » — et le `test_paths` du plugin créé : « fail-closed, onFailure block » |
| `INSTALLATION.md` non complété | « INSTALLATION nomme le hook et sa portée » |
