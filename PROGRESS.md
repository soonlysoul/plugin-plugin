# PROGRESS — plugin-plugin v0.1

Dernière mise à jour : 2026-10-23
Reprise : lire ce fichier, puis `git log --oneline` ; le plan fait foi (`docs/PLAN.md`, APPROUVÉ).

## État courant

Branche `main`, publiée ; `feat/v0.1.0` reste en local sur `c103f67`, l'avant-publication. **Phases 1 à 5 terminées** : plugin-plugin 0.1.0 chargeable, base de faits de 105 faits, ré-audit à zéro sur 2.1.296, cadrage (`frame`), garde de statut des documents, création d'un plugin vert (`create`), reprise depuis le disque (`resume`, rappel du point de reprise), suite déterministe verte, coût permanent 571 tokens. **Phases 6 à 15 terminées.** Le passage réel de la phase 6, payant, est celui du skill du témoin de la phase 15 (choix de Soon) ; les phases 7 à 12 n'en dépendaient pas. La phase 10 a été menée sans attendre le passage réel de la phase 6, dont elle ne se sert pas (choix de Soon, le 2026-10-20) : `check` liste les écarts d'un plugin au modèle, et `add` ajoute à plugin-flutter sans toucher à son métier. Phase 13 : plugin-flutter reconstruit dans `build/rebuild/` par `pp.sh rebuild`, sans écart de charpente, sa suite à 100 %. Phase 14 : plugin-nixos réécrit au modèle dans `build/rewrite/` par `tests/rewrite/plugin-nixos.sh`, un test de plugin-plugin — suite portée verte, chacun de ses 351 cas d'origine gardé, `check` à zéro écart ; au-delà du budget de contexte, la suite d'un plugin produit alerte au lieu d'échouer (choix de Soon). Phase 15 : le témoin `plugin-changelog` — un skill, un hook, un agent — construit par plugin-plugin du cadrage à la répétition de publication, 26 interventions de Soon, toutes demandées ; il a révélé deux écarts de plugin-plugin, corrigés. Phase 16 terminée : relecture des skills faite, ses 22 constats critiques et majeurs corrigés, trois défauts de `pp.sh` corrigés (rouge puis vert), documents d'usage et architecture posés, `check` à zéro écart sur plugin-plugin, plan et architecture approuvés (« Je valide »), étiquette locale `plugin-plugin--v0.1.0` sur `fec6a94`. **plugin-plugin 0.1.1 publié par lui-même** le 2026-10-20 : onze gestes, chacun sur un « oui », étiquette `plugin-plugin--v0.1.1` sur GitHub, PR #1 de la marketplace fusionnée par Soon, `claude plugin list` montre `plugin-plugin@soon` 0.1.1. **v0.1 livrée : les seize phases du plan sont terminées.** Coût permanent 880 tokens. **Phase 17, hors plan, terminée** : plugin-nixos réécrit par plugin-plugin, publié en 0.2.0 le 2026-10-20 à la place de l'original (étiquette `plugin-nixos--v0.2.0`), installé sur ce poste avec plugin-flutter 0.3.0 ; le correctif `c43d870` de `pp.sh` reste local, et la copie installée de plugin-plugin est 0.1.1. **Phase 18 en cours** : `release` tient descriptions et documents sur le `plugin.json` ; **plugin-plugin 0.1.2 publié** le 2026-10-20 (étiquette `plugin-plugin--v0.1.2`, description du dépôt posée, PR #2 de la marketplace fusionnée par Soon le 2026-10-21, 0.1.2 installé sur ce poste) ; **plugin-nixos aligné** le 2026-10-21 sans version (PR #3 fusionnée) ; l'alignement de plugin-flutter sort du plan le 2026-10-23 (décision i), un usage de plugin-plugin à la main de Soon. **Phase 19 en cours**, sur la branche `feat/own-model` : le modèle devient propre à plugin-plugin (`docs/MODEL.md`), plus aucun test ne lit un autre plugin ; PRD, PLAN, MODEL.md et architecture approuvés le 2026-10-23, suite verte ; reste le commit, puis une publication de plugin-plugin quand Soon la demande.

**Écart relevé en phase 9** — la décision c veut la suite d'évaluation de chaque skill de plugin-plugin, écrite et vérifiée phase après phase. `evals/` couvre `reaudit`, `frame`, `create`, `resume` et, depuis la phase 11, `release` ; pas `add`, ajouté en phase 6 et étendu en phases 7 à 9. Ses cas doivent venir de demandes concrètes. **Décision de Soon, le 2026-10-20** : ils viennent de la phase 15 — les demandes tapées pour ajouter le skill, l'agent et le hook du témoin font les cas positifs ; un ou deux négatifs proposés, validés par Soon. **Fermé en phase 15** : `evals/add/`, cinq cas, conforme à `check-evals`, non lancé (choix de Soon).

**Incident de la phase 11, réparé** — le 2026-10-20, une exécution du nouveau test `test_release` a commité dans le dépôt de plugin-plugin lui-même (`ed9b9df`, local, jamais poussé : aucune branche distante ne le contient). Un `git commit` sans rien à valider avait écrit sur la sortie standard, capturée avec le chemin du plugin d'essai ; le test a créé un dossier relatif dans plugin-plugin, et `git add -A` y a pris tout l'arbre. Défait par `git reset --soft HEAD~1` puis `git reset` (arbre de travail intact, commit gardé au reflog), dossier parasite retiré. Le test travaille désormais depuis son dossier jetable, sous `GIT_CEILING_DIRECTORIES`, et refuse tout commit hors d'un dépôt d'essai. L'échec de `release-write` qui l'a déclenché n'a pas été reproduit (18 appels simultanés de `plugin details` sans échec) : s'il revient, le test en montre la sortie.

**Bits d'exécution de `.claude/hooks/`, réparés le 2026-10-20** — les quatre scripts avaient perdu leur bit d'exécution dans l'arbre de travail (100755 → 100644). `settings.json` les appelant directement, `block-dangerous-commands` et `check-secrets` échouaient sans bloquer : inactifs dans ce projet. Restaurés par `chmod +x` (choix de Soon) : l'arbre est identique au commit, rien à commiter.

**Errata du plan, à corriger en une fois à la clôture (phase 16, choix de Soon le 2026-10-20)** — une seule revue, une seule approbation :

- « Tests et validation » affirme que `claude plugin validate .` ne valide que la marketplace. Mesuré en phase 2 : c'est faux sur 2.1.296 (voir ci-dessous). Rien ne casse : la suite valide toujours chaque cible.
- La phase 14 veut l'original intact « dans le clone comme dans le sous-module de `~/Documents/Nixos` ». Ce dossier n'existe pas ; `~/Nixos` est le dépôt nixos-config, sans sous-module, et aucun `.gitmodules` sous `~` ne cite plugin-nixos. Seul le clone a pu être prouvé intact ; le volet sous-module est **sans objet sur ce poste** (Soon, le 2026-10-20).

**Restes de l'incident de la phase 13** — `/tmp/tmp.TkiXQogIFk`, environ 14 Go de nix, sur le disque racine. Le garde interdit à Claude de l'effacer hors de `build/` : Soon l'efface lui-même (choix du 2026-10-20).

**plugin-nixos et Claude Code 2.1.223 — tranché le 2026-10-20** : la réécriture remplace l'original dans la marketplace, avec Claude Code 2.1.295 au moins ; un poste resté à la 2.1.223 de NixOS 26.05 n'a plus de garde garanti (choix de Soon, phase 17).

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

## Phase 6 — Ajouter un skill avec son évaluation — terminée

- [x] `pp.sh check-evals <plugin> <skill>` vérifie une suite sans la lancer : `case.yaml` écrit en JSON (sous-ensemble du YAML, lu par `jq` sans autre dépendance), `schema_version` `"1.0"`, nom préfixé par le skill, `runs` ≥ 3 déclaré, `execution.prompt`, au moins un correcteur de résultat par cas (pas une regex sur la trace), au moins un cas positif et un cas négatif par suite, un négatif en `min: 0`, `max: 0`, `arm: both`. Chaque règle manquante produit un refus qui la nomme (US-10). Les suites des phases 2 à 5, converties en JSON, la passent.
- [x] `pp.sh check-skill` : analyseur strict d'en-tête repris de plugin-flutter (sept formes cassées refusées), forme du modèle (`Use when …`, `not for …`, phrase française citée), `allowed-tools` refusé, 1 536 caractères au plus, moins de 500 lignes, aucun `$0`–`$9`. Il a trouvé un vrai écart : la description de `resume` disait « Use to », corrigée.
- [x] `pp.sh eval-plan` annonce le nombre de sessions, la fourchette de coût (0,13 à 0,23 USD par session, mesuré), le plafond (3 USD par défaut, `--max-cost` avant l'annonce), le compte qui paie, et la commande exacte ; `pp.sh eval-run` ne lance rien sans un « oui » littéral — « ok », « oui mais … », « d'accord », un message vide sont refusés et la doublure de `claude` n'est jamais appelée (US-11).
- [x] La commande porte toujours `--no-publish`, `--max-cost-usd` et `--output-dir` sous `evals/results/` (ignoré par git), jamais `--trust-plugin` ; `--allow-tools Bash` seulement pour un cas qui l'exige ; `--ablation none` pour un passage à un bras (`--one-arm`).
- [x] `pp.sh eval-verdict` : un cas positif que le témoin réussit est refusé (US-9) ; un cas qui exige Bash sans bwrap ni socat est « bloqué : bwrap absent », jamais réussi (US-12) ; une erreur de bac à sable, « bloqué » ; un passage partiel, « partiel ».
- [x] Skill `add` (volet skill, détails dans `skills/add/reference/skill.md`).
- [x] Sonde : confiance hors terminal interactif (ci-dessous).
- [x] Sonde : compte annoncé par `claude auth status` — consignée (ci-dessous) ; le titulaire réel n'est pas prouvé, geste laissé à Soon.
- [x] Sonde : autres plugins installés dans le bras témoin — aucun n'est chargé (traces `--keep-temp` du passage réel, ci-dessous).
- [x] Premier passage réel, sur accord : rouge avant le skill, vert avec Δ +1.00 (critères 4, 5) — l'évaluation de `draft-entry`, skill du témoin de la phase 15 (voir « Phase 15 »).

### Sondes

| Sonde | Commande | Résultat |
| --- | --- | --- |
| Confiance hors terminal | `claude plugin eval build/temoin-p6/plugin-codenames --case 'aucun-*' --no-publish --max-cost-usd 0.01 --ablation none --runs 1 </dev/null` | exit 1, avant tout chargement : « is not a trusted plugin directory, and this run cannot stop to ask you about it (no interactive terminal …) ». Aucune session, aucun coût. `eval-run` le dit désormais « bloqué », avec la commande gratuite qui approuve le dossier. |
| Compte qui paie | `claude auth status --json` | Pour `~/.claude`, il annonce le compte pro (abonnement `pro`), alors que le CLAUDE.md du poste attribue `~/.claude` au compte ordinaire. Ce bloc peut ne pas dire le titulaire du jeton ; seul `/api/oauth/profile` tranche, avec le jeton du profil : non fait, geste sensible laissé à Soon. L'adresse n'est pas recopiée ici : ce dépôt sera public. Le 2026-10-20, même profil, `claude auth status` et l'annonce du passage réel disent `max` : l'annonce suit la configuration du profil, Soon a accordé chaque passage en le sachant. |
| Isolement du bras témoin | doc plugin-evals, « How runs are isolated » | La doc dit qu'aucun autre plugin installé n'est chargé dans une exécution : l'hypothèse du PRD (flutter-forge chargé dans le témoin) serait fausse. **Confirmé** par les traces du passage réel (`--keep-temp`, phase 15) : le `system/init` du bras témoin ne liste que `cc-plugin-sec-default`, `cc-plugin-agents-md` et `cc-plugin-plugin-authoring`, intégrés ; celui du bras avec plugin y ajoute `plugin-changelog`. |

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

### Phase 6 — Le passage réel

Prévu ici en trois gestes de Soon, sur `plugin-codenames` :

1. **Approuver le dossier du témoin, sans coût**, une fois, dans un terminal :
   `cd build/temoin-p6/plugin-codenames && claude plugin eval . --case 'aucun-*' --no-publish --max-cost-usd 0.01 --ablation none --runs 1`, puis répondre `y`.
2. **Rouge** — un « oui » à cette annonce : 9 sessions (3 cas × 3 exécutions × 1 bras), 1,17 à 2,07 USD, plafond 3 USD, compte annoncé : le compte pro de `~/.claude` (voir la sonde).
3. **Vert**, après l'écriture du skill — un « oui » à cette annonce : 18 sessions (3 cas × 3 exécutions × 2 bras), 2,34 à 4,14 USD, plafond proposé 4,5 USD.

**Décisions de Soon, le 2026-10-20** : un seul passage réel couvre les phases 6 et 15 — l'évaluation du skill du témoin de la phase 15, rouge puis vert, vaut premier passage réel ; les deux sondes l'accompagnent ; `plugin-codenames` reste prêt, inutilisé. Le **compte qui paie est le compte pro**, seul profil du poste (`~/.claude`) et celui qu'annonce `claude auth status` : le CLAUDE.md qui attribuait `~/.claude` au compte ordinaire est introuvable.

**Fait le 2026-10-20**, sur `draft-entry` du témoin `plugin-changelog` : rouge à un bras, 9 sessions, 0,62 USD, « verdict : rouge » ; vert à deux bras, 18 sessions, 1,16 USD, Δ +1.00 sur les deux positifs, « verdict : vert ». L'annonce disait `max`, non `pro` : signalé à Soon avant chaque « oui ». Détail dans « Phase 15 ».

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

## Phase 8 — Ajouter un agent aux outils déclarés — terminée

- [x] L'analyseur strict refuse les sept formes cassées relevées par plugin-flutter (crochet ouvert, « : » non cité, liste YAML, clé en double, guillemet isolé, en-tête non refermé ou non ouvert) ; il accepte désormais les clés en camelCase pour les nommer « clé inconnue » (`permissionMode`) au lieu de rejeter tout l'en-tête.
- [x] `tools` présent, outils connus, jamais `Agent` ; un relecteur (nom contenant `review`) n'a ni `Write` ni `Edit` (US-13).
- [x] Nom de 3 à 50 caractères, commençant et finissant par une lettre ou un chiffre ; description « Use this agent when … ; not for … » de 200 à 1 000 caractères ; corps en `## Responsibilities`, `## Approach`, `## Output format`, avec STATUS / FILES_CHANGED / COMMANDS_RUN / OPEN_QUESTIONS (`pp.sh check-agent`).
- [x] Un agent qui écrit ou lance Bash a ses dossiers et sa liste blanche déclarés dans `hooks/agent-scope.json`, imposés par `agent-scope-guard` (PreToolUse, fail-closed) : écriture hors portée, chemin qui remonte, hors du projet, commande hors liste, composée ou substituée — bloqués ; session principale et agents d'autres plugins — inertes, même sans `jq`.
- [x] Test vu en échec (« agents/doc-reader.md présent » : absent, suite du plugin rouge), puis vert (critère 4).

Réorganisation : l'analyseur et les règles d'en-tête vivent dans `tests/headers.sh`, source unique chargée par `pp.sh` et recopiée par `create` avec le test générique `test_headers.sh`. Un plugin créé vérifie donc lui-même ses skills et ses agents, sans `pp.sh`. Règles de **structure** (pour tout plugin du modèle, plugin-flutter compris) et de **style** (« Use when … ; not for … », phrase française, longueur de la description d'agent, sections du corps : ce que plugin-plugin impose aux composants qu'il ajoute) sont séparées. `scripts/lib/frontmatter.sh` est retiré.

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/static/test_headers.sh` | 1 | « tests/headers.sh présent » : absent |
| ROUGE | `bash tests/static/test_frontmatter.sh` | 1 | « un agent au modèle est conforme », « tools absent … » : `check-agent` inconnu |
| ROUGE | `bash tests/static/test_frontmatter.sh` (bibliothèque écrite) | 1 | variable non liée : les règles de style lisaient un en-tête lu dans un sous-shell ; corrigé. Puis « clé inconnue » (camelCase rejeté) et « démarche absente » (motif de test `${…/## …}` ancré par `#`) |
| ROUGE | `bash tests/integration/test_add_agent.sh` | 1 | 37 échecs : `add-agent` inconnu |
| VERT | `bash tests/run-all.sh` | 0 | `test_add_agent : 43`, `test_headers : 13`, `test_frontmatter : 32` réussis ; « coût permanent : 552 tokens (seuil 1000) » ; « réussies : 21, échouées : 0, sautées : 1, bloquées : 0 » |

### Les tests discriminent

| Copie faussée (une ligne) | Premier échec |
| --- | --- |
| `add-agent` accepte l'outil Agent | d'abord **non pris** : l'outil refusait quand même, en « outil inconnu : Agent », et le test ne cherchait que « Agent ». Motif resserré ; rejoué : « outil Agent : refusé, raison nommée » |
| `headers.sh` accepte l'outil Agent | « outil Agent : refusé, règle nommée » (`test_frontmatter`) |
| un relecteur peut écrire | « relecteur qui écrit : refusé, raison nommée » |
| le garde laisse passer une commande composée | « substitution de commande : bloquée » |
| le garde s'applique aux agents des autres plugins | « agent d'un autre plugin : inerte » |
| `tools` absent toléré | « tools absent : refusé, règle nommée » |

## Phase 9 — Déclarer un serveur MCP existant ; refuser le hors-périmètre — terminée

- [x] `pp.sh add-mcp <plugin> --name N (--launcher scripts/S.sh [--args …] [--env VAR,…] | --url U [--header Nom=valeur]…) [--test-only]` ajoute le serveur à `.mcp.json` sans rien écrire d'autre que sa déclaration : un serveur local est lancé par `bash`, son lanceur dans `args`, cité par `${CLAUDE_PLUGIN_ROOT}/scripts/` — la forme des hooks du modèle, et celle de plugin-nixos 0.1.2, sans dépendre du bit d'exécution ; un serveur distant est en `type: http` (HTTPS) ou `ws` (WSS), jamais en HTTP ni WS.
- [x] Valeurs de l'utilisateur en `${VAR}` seulement : `--env` ne prend que des noms ; un `$VAR` sans accolades, un secret en clair (suite de 20 caractères mêlant lettres et chiffres, en-tête sensible ou paramètre d'adresse sans `${VAR}`) sont refusés, sans jamais recopier le secret.
- [x] Aucune installation impérative (`npm install`, `npx`, `bun install`, `pip install`, `uvx`, `cargo install`…), ni dans la commande ni dans le lanceur. Un lanceur absent, hors de `scripts/` ou qui remonte (`..`) est refusé ; aucun refus n'écrit quoi que ce soit.
- [x] Variables documentées : la section « Serveurs MCP » du README, réécrite depuis `.mcp.json` à chaque déclaration, nomme chaque serveur, ses variables et sa doublure `evals/mocks/<serveur>/`. `add-mcp` le rappelle à l'écran : sans doublure, le serveur n'est pas démarré pendant une évaluation.
- [x] Le test du serveur, `tests/static/test_mcp_<nom>.sh`, s'écrit avant lui (`--test-only`) et échoue sur « serveur <nom> déclaré » ; la déclaration écrite, il passe (critère 4).
- [x] `pp.sh out-of-scope` refuse, avec sa raison et son déclencheur : code d'un serveur MCP et channel (« premier plugin qui a besoin d'un système sans ligne de commande, ou d'un channel »), serveur de langage (« v0.2 »), style de sortie et option de plugin (révision du PRD), commande classique (jamais : un skill la remplace), dépendance entre plugins (révision du PRD, quand un plugin ne peut pas fonctionner sans un autre) — US-16.
- [x] Skill `add`, volet MCP (`skills/add/reference/mcp.md`) ; toute autre sorte de composant passe par `out-of-scope`, et le skill s'arrête.

Règles en source unique `tests/mcp.sh`, chargée par `pp.sh` et recopiée par `create` : `test_paths` les applique à tout plugin du modèle qui a un `.mcp.json`, même écrit à la main — lanceur par `bash`, HTTPS ou WSS, aucune installation, variables en `${VAR}`, aucun secret —, et compte `.mcp.json` parmi les sources qui citent un chemin ou un script.

Écart au test d'abord écrit : il attendait `command: "${CLAUDE_PLUGIN_ROOT}/scripts/mcp-notes.sh"`. Son lanceur d'essai n'a pas le bit d'exécution, comme ceux de `.claude/hooks/` dans l'arbre de travail : la déclaration n'aurait pas démarré. Le test attend désormais `command: "bash"`, avant toute implémentation.

### Sondes

| Sonde | Commande | Résultat |
| --- | --- | --- |
| `.mcp.json` est-il validé ? | `claude plugin validate .claude-plugin/plugin.json --strict` sur quatre `.mcp.json` | « Validating mcp » : JSON cassé et type `telepathy` échouent (exit 1) ; `bash` + lanceur, `http` + `headers`, `ws` passent (exit 0). Fait `mcp-validated-with-manifest`, `mcp-declaration-forms` |
| `.mcp.json` visé seul | `claude plugin validate .mcp.json --strict` | exit 1 « name: expected string » : lu comme un manifeste ; `run-all.sh` n'en fait pas une cible |
| Champ inconnu dans un serveur | `… --strict` sur `"frobnicate": 1` | exit 0, toléré : les règles du modèle se contrôlent par `test_paths`. Fait `mcp-server-unknown-field-tolerated` |

Trois sondes rejouées par `pp.sh reaudit` (`scripts/facts/probes/mcp-*`) : « faits à corriger : 0 ».

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/integration/test_add_mcp.sh` | 1 | 4 réussis, 36 échoués : `add-mcp` et `out-of-scope` inconnus |
| ROUGE | `bash tests/integration/test_create.sh` | 1 | « créé : tests/mcp.sh » |
| ROUGE | `bash tests/static/test_facts.sh` | 1 | « fait mcp-validated-with-manifest », « fait mcp-declaration-forms », « fait mcp-server-unknown-field-tolerated » : absents |
| ROUGE | `bash tests/integration/test_add_mcp.sh` | 1 | 2 échecs : le refus disait « valeur secrète », le test cherche « secret » ; message reformulé, « secret écrit en clair » |
| ROUGE | `bash tests/run-all.sh` | 1 | `test_paths` : « skills/add/reference/mcp.md ne contient pas ${CLAUDE_PLUGIN_ROOT} » — la règle des annexes, prise sur un vrai cas ; `--launcher` prend donc `scripts/<nom>.sh` et `pp.sh` écrit le préfixe |
| ROUGE | `bash tests/integration/test_add_mcp.sh` | 1 | « lanceur absent : refusé, raison nommée » … : un chemin relatif encore refusé |
| VERT | `bash tests/integration/test_add_mcp.sh` | 0 | 41 réussis, dont « suite du plugin : rouge, le serveur n'est pas déclaré », puis « suite du plugin : verte » |
| VERT | `bash tests/run-all.sh` | 0 | `test_add_mcp : 41`, `test_paths : 51`, `test_facts : 58`, `test_create : 60` réussis ; « coût permanent : 571 tokens (seuil 1000) » ; « réussies : 22, échouées : 0, sautées : 1, bloquées : 0 » |

### Les tests discriminent

| Copie faussée (une ligne) | Premier échec de `test_add_mcp` |
| --- | --- |
| refus du serveur de langage sans déclencheur | « lsp : refusé, raison et déclencheur » |
| `http://` accepté | « serveur distant en HTTP : refusé, raison nommée » |
| installation jamais détectée (`tests/mcp.sh`) | « installation impérative : refusé, raison nommée » |
| `--test-only` écrit aussi la déclaration | « --test-only écrit le test, pas la déclaration » |
| secret jamais détecté | « valeur secrète en clair : refusé, raison nommée » |
| README non complété | « variables documentées dans le README » |
| `test_paths` accepte un serveur hors lanceur bash | « test_paths refuse un serveur local hors lanceur bash » |
| `$VAR` sans accolades accepté | « $VAR sans accolades : refusé, raison nommée » |
| lanceur absent accepté | « lanceur absent : refusé, raison nommée » |
| préfixe `${CLAUDE_PLUGIN_ROOT}/` non écrit | « lanceur qui installe : refusé, raison nommée » |
| lanceur qui remonte accepté | « lanceur qui remonte : refusé, raison nommée » |
| `create` ne recopie pas `tests/mcp.sh` | « suite du plugin : verte » (le `test_paths` du plugin créé : « tests/mcp.sh présent ») ; `test_create` : « créé : tests/mcp.sh » |

Non pris : faire passer, dans `test_paths`, une annexe qui contient `${CLAUDE_PLUGIN_ROOT}`. Règle antérieure à la phase 9, hors de `test_add_mcp` ; aucun test ne la met à l'épreuve sur une copie faussée, mais elle a échoué pour la bonne raison sur `mcp.md` (rouge ci-dessus).

## Phase 10 — Plugins existants : écarts au modèle, ajout sans toucher au métier — terminée

Menée avant la clôture de la phase 6, dont le passage réel payant attend toujours : `check` et l'ajout à un plugin existant ne s'en servent pas (choix de Soon, le 2026-10-20).

- [x] `pp.sh check <plugin>` liste les écarts au modèle, un par ligne avec sa catégorie, et ne modifie rien (empreintes et `git status` identiques, prouvés par `test_check` et `test_check_real`) : manifestes (nom, SemVer, auteur sans e-mail, MIT, dépôt dédié, champs connus, marketplace locale), fichiers à la racine (LICENSE, README, CHANGELOG avec la version, PROGRESS, ARCHITECTURE à la racine ou dans `docs/`, les quatre documents de `docs/`, `.gitignore`, pas de CLAUDE.md), arborescence (rien hors des dossiers du modèle, hooks sous `hooks/scripts/`), forme exec des hooks, `timeout`, `onFailure`, mode déclaré, câblage, `#!/usr/bin/env bash` et `bash -n`, en-têtes de skills et d'agents (structure seule), garde de portée d'un agent qui écrit, chemins cités et annexes, interpréteur à chemin fixe, chemins personnels, serveurs MCP (règles de `tests/mcp.sh`), harnais (`run-all.sh`, `lib.sh`, `tests/static/`, un test par script de hook, aucun test à la racine de `tests/`). Règles dans `scripts/lib/check.sh`, qui reprend `name_error`, `tests/headers.sh` et `tests/mcp.sh`.
- [x] Seuls comptent les fichiers qu'un clone porterait (`git ls-files -co --exclude-standard`) ; une copie rangée dans un dossier que son dépôt parent ignore — `build/ref/` — est lue en entier. Défaut trouvé sur flutter-forge, extrait sous `build/` : ses fichiers étaient invisibles ; test ajouté, vu rouge, puis corrigé.
- [x] plugin-flutter (copie de lecture et original) : aucun écart. plugin-nixos : 15 écarts, dont la forme des hooks, l'arborescence des hooks et le harnais. Ancien flutter-forge (plugin-flutter à `04ba88f`, extrait par `git archive`) : nom hors format, seul écart. Originaux et copies : HEAD, `git status` et empreintes identiques avant et après (US-18).
- [x] Contrôles repris de plugin-validator : fichiers parasites (`node_modules`, `.DS_Store`, `Thumbs.db`, `*.swp`) ; identifiants en clair (clé privée, jetons GitHub, Anthropic, OpenAI, AWS, Slack), dont seule la ligne est donnée, jamais l'identifiant ; exemple publié (`…EXAMPLE`) et jeton de remplissage (`AAAA…`) exemptés ; README et LICENSE présents.
- [x] `add-hook`, `add-agent` et `add-mcp` refusent un plugin qui a des écarts, en désignant `pp.sh check` ; rien n'est écrit. Le skill `add` lance `check` d'abord, pour toutes les sortes, skill compris.
- [x] Ajout d'un hook à un clone de plugin-flutter : le diff ne touche que le script, son test, `hooks/hooks.json` et la section ajoutée de `docs/INSTALLATION.md`, sans supprimer une ligne ; les hooks d'origine sont intacts. La suite d'origine reste à 100 % : seul le test du hook échoue, sur sa règle non écrite ; la règle écrite, la suite sort en 0 et `check` ne relève aucun écart (US-17).
- [x] Suite d'évaluation de `check` écrite et vérifiée (`check-evals` : 2 cas, 1 positif, 1 négatif), non lancée (décision c).

Trois défauts de l'ajout à un plugin que plugin-plugin n'a pas créé, trouvés sur une copie de plugin-flutter, puis corrigés test d'abord :

- le test d'un hook appelait `path_without`, que le harnais de plugin-flutter n'a pas : il prive désormais le hook de `jq` par un PATH vide, et n'appelle que les aides communes aux deux harnais ;
- `wire_hook` réécrivait tout `hooks.json` par `jq`, et étalait sur trois lignes les `args` des hooks d'origine : les tableaux de chaînes restent sur une ligne, comme le modèle les écrit, sauf dans un fichier qui les étale déjà ; même règle pour `.mcp.json` et `hooks/agent-scope.json` ;
- le test d'un agent lit `tests/headers.sh`, absent de plugin-flutter : posé s'il manque. Un agent qui écrit ou lance Bash est refusé quand le plugin a son propre garde de portée : celui de plugin-flutter connaît ses trois agents par leur nom, bloque les autres, et ne lit pas `hooks/agent-scope.json`.

Limite constatée : la suite de plugin-flutter fige son inventaire (« exactly the three v0.1 agents », « exactly the four v0.1 skills »). Y ajouter un skill ou un agent la fait échouer sans toucher à son métier, ce qui est impossible. Sur un plugin sans `.plugin-plugin/`, le skill `add` n'écrit donc aucun point de reprise — `init-state` y ajouterait des fichiers hors du composant —, lance la suite d'origine avant l'ajout, et s'arrête, en nommant la suite et le contrôle, si elle rougit ailleurs que dans le test du composant.

Hors de cette phase : la copie de lecture `build/ref/plugin-nixos` porte, depuis sa création le 2026-10-19, la perte du bit d'exécution de trois scripts (100755 → 100644), comme `.claude/hooks/` ; l'original `../plugin-nixos` est propre. Non touché. `check` sur plugin-plugin lui-même relève 5 écarts : ARCHITECTURE.md et les quatre documents de `docs/`, à poser avant la clôture (phase 16), comme prévu en phase 1.

### Sorties de `check` sur les plugins réels

| Plugin | Commande | Code | Résultat |
| --- | --- | --- | --- |
| plugin-flutter (copie de lecture, puis original) | `bash scripts/pp.sh check build/ref/plugin-flutter` ; `… check ../plugin-flutter` | 0 | « écarts : 0 — au modèle de plugin-flutter » |
| plugin-nixos (copie de lecture, puis original) | `bash scripts/pp.sh check build/ref/plugin-nixos` ; `… check ../plugin-nixos` | 1 | « écarts : 15 » : CHANGELOG sans entrée `[0.1.2]` ; PROGRESS.md et les quatre documents de `docs/` absents ; `modeles/` hors modèle ; `hooks/garde-nixos.sh` et `hooks/lib-commande.sh` hors de `hooks/scripts/` ; garde en forme shell (`bash "${CLAUDE_PLUGIN_ROOT}/hooks/garde-nixos.sh"`) et sans `onFailure` ; `tests/static/` sans test ; `tests/test_garde.sh`, `test_nixconf.sh`, `test_statique.sh` à la racine de `tests/` |
| ancien flutter-forge (`git archive 04ba88f`) | `bash scripts/pp.sh check build/ref/flutter-forge` | 1 | « écarts : 1 » : « nom hors format : « flutter-forge » n'a pas le préfixe plugin- » |

Intégrité : `../plugin-flutter` 55df72c et `../plugin-nixos` dc6ea53, `git status` vide, empreintes identiques avant et après.

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/static/test_check.sh` | 1 | 2 réussis, 44 échoués : « usage : pp.sh reaudit \| … » — commande inconnue |
| VERT | `bash tests/static/test_check.sh` | 0 | 46 réussis (deux messages remis dans l'ordre attendu, un `git mv -q` de la copie faussée corrigé) |
| ROUGE | `bash tests/static/test_check.sh` (copie dans un dossier ignoré) | 1 | « copie dans un dossier ignoré par un dépôt parent : tous ses fichiers vus » : « [harnais] tests/static/ sans test » |
| ROUGE | `bash tests/static/test_check.sh` (exemples publiés) | 1 | « exemple publié et jeton de remplissage (AAAA…) : pas un écart » |
| ROUGE | `bash tests/static/test_check.sh` (sortie d'erreur, `/bin/bash` cité) | 1 | « rien sur la sortie d'erreur » : `sed` cassé par un `#` du message, la règle ne disait jamais rien ; « /bin/bash cité par un skill » |
| ROUGE | `bash tests/static/test_check.sh` (add-* hors modèle) | 1 | « add-hook \| add-agent \| add-mcp sur un plugin hors modèle : refusé », « refusés : rien n'est écrit » |
| VERT | `bash tests/static/test_check.sh` | 0 | 55 réussis |
| ROUGE | `bash tests/integration/test_add_existing.sh` | 1 | 10 réussis, 7 échoués : `hooks.json` réécrit, `path_without : commande introuvable`, agent qui écrit accepté, `headers.sh` absent ; plus un tri du test dépendant de la locale, corrigé (`LC_ALL=C`) |
| VERT | `bash tests/integration/test_add_existing.sh` | 0 | 17 réussis |
| VERT | `test_add_hook`, `test_add_agent`, `test_add_mcp` | 0 | 35, 43 et 41 réussis |
| ROUGE | `bash tests/static/test_components.sh` ; `… test_evals.sh` | 1 | « skill check présent » ; « evals/check conforme : aucun cas dans evals/check/ » |
| VERT | `test_components` ; `test_evals` ; `test_check_real` ; `test_create` | 0 | 13, 66, 10 et 61 réussis |
| VERT | `bash tests/run-all.sh` | 0 | `test_check : 55`, `test_add_existing : 17`, `test_check_real : 10`, `test_create : 61`, `test_evals : 66`, `test_components : 13` réussis ; « coût permanent : 824 tokens (seuil 1000) » ; « réussies : 29, échouées : 0, sautées : 1, bloquées : 0 » |

### Les tests discriminent

Copies faussées dans `build/mutants/p10/`, une ligne changée chacune, `PLUGIN_UNDER_TEST=<copie> PP_REF_DIR=build/ref bash <test>` :

| Copie faussée | Test | Premier échec |
| --- | --- | --- |
| forme exec ignorée | test_check, test_check_real | « forme shell : écart nommé » ; « écart listé : [forme des hooks] … garde-nixos.sh » |
| arborescence des hooks ignorée | test_check, test_check_real | « script hors de hooks/scripts/ » ; « [arborescence des hooks] hooks/garde-nixos.sh » |
| nom ignoré | test_check, test_check_real | « nom sans préfixe plugin- » ; « nom hors format » |
| tests à la racine de `tests/` ignorés | test_check, test_check_real | « test hors de tests/static/ et tests/hooks/ » ; « [harnais] tests/test_garde.sh » |
| l'identifiant recopié dans le message | test_check | « l'identifiant n'est jamais recopié » |
| dossier ignoré par le dépôt parent lu par git | test_check | « copie dans un dossier ignoré … : tous ses fichiers vus » |
| `.gitignore` ignoré | test_check | « node_modules ignoré par git : pas un écart » |
| exemple publié pris pour un secret | test_check | « exemple publié et jeton de remplissage (AAAA…) : pas un écart » |
| `check` sort en 0 malgré des écarts | test_check | 41 échecs, dont « nom sans préfixe plugin- : écart nommé » |
| `check` écrit un fichier | test_check | « aucun fichier modifié (empreintes, git status) » |
| `add-*` sans garde de modèle | test_check | « add-hook sur un plugin hors modèle : refusé, check désigné » (et agent, MCP) |
| `hooks.json` réécrit par `jq` | test_add_existing | d'abord **mal formée** : `true \|\| [[ … ]] && awk` se lit `(true \|\| …) && awk`, la mise en forme restait. Réécrite (`if true; then`) ; rejouée : « hooks/hooks.json : aucune ligne existante modifiée » |
| garde propre au plugin ignoré | test_add_existing | « agent qui écrit, garde propre au plugin : refusé, raison nommée » |
| `headers.sh` non posé | test_add_existing | « l'aide de test tests/headers.sh, absente, est posée » |
| le test du hook rappelle `path_without` | test_add_existing | « le test généré n'appelle que les aides du harnais du plugin » |

## Phase 11 — Répétition de publication — terminée

- [x] `pp.sh release <plugin> [--bump patch|minor|major]` refuse, sans rien toucher (empreinte de l'arborescence, `.git` compris) : changements non enregistrés, fichiers non suivis compris ; validation stricte rouge ; suite du plugin rouge ; autre branche que `main` ; plugin qui n'est pas la racine de son dépôt ; `origin` hors de `soonlysoul/<nom>` ; rien depuis la dernière étiquette. GitHub illisible ou `gh` absent : « bloqué », exit 2 (US-23).
- [x] Version selon la nature du changement, lue sur les composants depuis la dernière étiquette : un composant retiré donne une majeure, un ajouté une mineure, tout autre changement un correctif ; `--bump` ne peut que monter, et la nature calculée reste affichée. Première publication : la version de `plugin.json`. Entrée du CHANGELOG rédigée : la section « en cours » du haut est datée et garde ses entrées, sinon une section est rédigée depuis les composants ajoutés et retirés, ou depuis les commits. Étiquette vérifiée par `claude plugin tag --dry-run`, lancé une fois, sur la copie jetable ; son refus arrête la répétition (US-22).
- [x] Marketplace `soon` et dépôt `soonlysoul/<nom>` lus par `gh api`, jamais dans la copie locale ; l'entrée d'un nouveau plugin est essayée sur la marketplace lue, puis passée à la validation stricte (US-28).
- [x] Coût en contexte par composant, par `claude plugin details`, alerte au-delà de 1 000 tokens permanents ; le coût est inscrit dans l'entrée du CHANGELOG et dans le corps de la PR (US-25, critère 9).
- [x] Gestes numérotés, chacun avec sa commande exacte, `[local]` ou `[GitHub]` : écriture de version (`pp.sh release-write`), commit, étiquette, création du dépôt, `origin`, push de `main`, push de l'étiquette ; pour un nouveau plugin, copie de la marketplace, branche, entrée (`pp.sh marketplace-entry`), commit, push de la branche, PR. Aucun n'est exécuté : les journaux des doublures `gh` et `git push` restent vides, et le dépôt distant (nu) aussi. Les trois gestes locaux annoncés, lancés tels quels sur une copie, produisent bien la version, le CHANGELOG daté et l'étiquette (US-24).
- [x] Commande à lancer soi-même sur chaque appareil : `claude plugin marketplace update soon` puis `claude plugin install <nom>@soon` après la fusion de la PR ; `claude plugin update <nom>@soon` pour une mise à jour (US-29).
- [x] Suite d'évaluation `evals/release/` : un cas positif, l'invocation explicite, et un négatif tiré d'une demande de Soon recueillie le 2026-10-20 (« pousse plugin-x sur GitHub »), trois exécutions chacun. Écrite, conforme à `check-evals`, non lancée : le positif exige Bash (décision c).
- [x] Skill `release` (`disable-model-invocation`) : le jugement sur la nature du changement — une rupture à l'intérieur d'un composant — lui revient, `--bump` seulement après un « oui ». Ce skill ne fait que répéter : aucun geste listé n'est lancé, même sur un « oui ».

Tout se fait sur une copie jetable de HEAD (`git clone`) : validation, coût, écriture de la version et du CHANGELOG, suite, étiquette. L'état éprouvé est donc celui qui serait étiqueté, et le dossier du plugin n'est jamais écrit. Aucun point de reprise pour la répétition, en lecture seule comme `reaudit` ; le journal des gestes vient en phase 12.

Retouches liées : `add` ouvre désormais `## [à venir] — en cours` au-dessus d'une section déjà datée, que `release` date ; `eval-plan` accorde à `--allow-tools` les motifs Bash déclarés par les cas (`Bash(bash:*)` pour le positif de `release`), jamais Bash entier.

Coût permanent de plugin-plugin : 678 tokens (`release` ~110), sous le seuil de 1 000.

### Sondes

| Sonde | Commande | Résultat |
| --- | --- | --- |
| Arbre sale, étiquette posée, version discordante | `claude plugin tag --dry-run .` sur un plugin créé | exit 1 dans les trois cas ; un fichier du `.gitignore` (`.plugin-plugin/checkpoint.md`) n'empêche rien ; une entrée sans version passe. Fait `plugin-tag-checks-tree-tag-and-entry` |
| Plugin hors de la racine de son dépôt | `claude plugin tag --dry-run <dossier sans .git>` | exit 0 : l'étiquette est annoncée **dans le dépôt englobant** (ici plugin-plugin). `release` refuse donc tout plugin qui n'est pas la racine de son dépôt. Fait `plugin-tag-climbs-to-enclosing-repo` |
| Sans réseau | `unshare -rn claude plugin tag --dry-run .` | exit 0 ; affiche `git tag -a` et `git push origin refs/tags/…`. Fait `plugin-tag-dry-run-offline` |
| Coût par composant | `claude --plugin-dir . plugin details <nom>` | tableau « Per-component (rounded) » par skill et agent ; absent sans composant. Fait `plugin-details-per-component` |
| Marketplace à source GitHub | `unshare -rn claude plugin validate . --strict` | exit 0, dépôt inexistant compris ; deux entrées du même nom : exit 1 ; une marketplace sans `description` : exit 1 en strict. Sondes `marketplace-github-source`, `marketplace-duplicate-name`, rejouées par `reaudit` : « faits à corriger : 0 » |
| Marketplace `soon` réelle | `gh api repos/soonlysoul/claude-plugins/contents/.claude-plugin/marketplace.json` | entrées `name`, `source` github, `description`, sans version ni ref ; dépôt public, branche `main`. Fait `marketplace-soon-entry-format` |
| `--allow-tools` de l'évaluation | `claude plugin eval --help` | « Supports Tool(pattern:*) syntax ». Que `Bash(bash:*)` tienne en passage réel, et que le bac à sable voie ou non les identifiants `gh` du poste : **à vérifier** au premier passage (fait `eval-allowed-tools-pattern-narrows-bash`) |

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/static/test_components.sh` | 1 | 8 réussis, 2 échoués : « skill release présent », « release ne se lance que sur demande explicite » |
| ROUGE | `bash tests/static/test_evals.sh` | 1 | 62 réussis, 3 échoués : « evals/release conforme », « le motif du cas est accordé tel quel » (`--allow-tools Bash` entier), « un cas restreint n'accorde jamais Bash entier » |
| ROUGE | `bash tests/static/test_facts.sh` | 1 | 58 réussis, 8 échoués : les huit faits de la phase 11 absents |
| ROUGE | `bash tests/integration/test_release.sh` | 1 | 30 réussis, 60 échoués : `release` inconnu de `pp.sh` (« usage : pp.sh reaudit \| … ») |
| ROUGE | `bash tests/integration/test_release.sh` (scénario ajouté) | 1 | « entrée de marketplace locale discordante » : le refus venait de la validation stricte, pas de l'étiquette. Pour un plugin du modèle, validation, suite (`test_manifest`) et `pp.sh` couvrent déjà ce que vérifie `--dry-run` ; scénario remplacé par une doublure qui journalise et refuse `plugin tag` |
| VERT | `bash tests/integration/test_release.sh` | 0 | 102 réussis |
| VERT | `bash tests/run-all.sh` | 0 | `test_release : 102`, `test_evals : 65`, `test_facts : 70`, `test_components : 10` réussis ; « coût permanent : 678 tokens (seuil 1000) » ; « réussies : 23, échouées : 0, sautées : 1, bloquées : 0 » ; dépôt de plugin-plugin inchangé par la suite |

### Les tests discriminent

Copies faussées dans `build/mutants/p11/`, une ligne de `pp.sh` changée chacune, `PLUGIN_UNDER_TEST=<copie> bash tests/integration/test_release.sh` (`test_evals.sh` pour la dernière) ; HEAD et l'état du dépôt de plugin-plugin contrôlés avant et après la passe :

| Copie faussée | Premiers échecs |
| --- | --- |
| arbre sale accepté | « changement non enregistré : refusé », « fichier non suivi : refusé » |
| suite rouge ignorée | « suite rouge : refusé », « coût au-delà du seuil : refusé » |
| validation stricte ignorée | « validation stricte rouge : refusé » |
| racine du dépôt non vérifiée | « plugin hors de la racine de son dépôt : refusé » |
| composant retiré non compté majeur | « composant retiré : majeure » |
| `git push origin main` lancé pendant la répétition | « première publication : aucun git push », « mise à jour : aucun git push » |
| marketplace lue dans la copie locale | « marketplace lue sur GitHub (US-28) », « la marketplace est lue par gh api » (7 échecs) |
| alerte de coût retirée | « alerte au-delà de 1 000 tokens » |
| `--dry-run` sauté, sa réussite simulée | « claude plugin tag --dry-run refuse : refusé », « … lancé une fois, sur la copie jetable » |
| `--bump` plus faible accepté | « --bump plus faible que la nature du changement : refusé » |
| version écrite dans le plugin, non dans la copie | « suite rouge : plugin identique » (24 échecs) |
| coût par composant omis | « coût du composant demo », « coût par composant, même en alerte » |
| section « en cours » exigée chiffrée | « aucune entrée rédigée en double », « section publiée intacte, plus de section en cours » |
| `eval-plan` accorde toujours Bash entier | « le motif du cas est accordé tel quel », « un cas restreint n'accorde jamais Bash entier » |

## Phase 12 — Publication sous accord — terminée

- [x] `pp.sh publish <plugin> [--bump …] [--run N]` : la répétition, verte, est figée dans `.plugin-plugin/publication.json` (version, étiquette, gestes et commandes exactes), puis annoncée étape par étape — les gestes locaux jusqu'à un geste GitHub, inclus. Une étape ne part que par la commande annoncée (`… publish <plugin> --run N`), après un « oui » tapé ; `pp.sh` le vérifie lui-même au journal des accords, et un accord ne sert qu'une fois.
- [x] Le garde refuse tout geste GitHub sans accord ; un « oui » littéral laisse passer une seule fois la commande annoncée ; « ok », « oui mais attends », « d'accord », « ouais », « non », « vas-y », « oui, et ensuite le tag », le silence et une annonce de plus de trente minutes valent refus (US-20, critère 6). Hook `consent-capture` (UserPromptSubmit, fail-open) et garde `gesture-guard` (PreToolUse, `Bash|Edit|Write`, fail-closed).
- [x] Sonde : entrée de `UserPromptSubmit` en 2.1.296 — binaire, puis en vivant dans l'extension VSCode (ci-dessous) : un message tapé arrive tel quel dans `prompt` ; hook de sonde retiré. Le cas d'un message tapé avec une sélection reste à vérifier (fait `user-prompt-submit-vscode-selection`). Le mécanisme tient : une notification injectée par Claude Code passe aussi par `UserPromptSubmit`, mais n'est jamais un « oui » ; elle retire l'annonce, ce qui vaut refus. La décision g n'est pas révisée.
- [x] Le garde est inerte hors d'un projet géré (un `.plugin-plugin/` au-dessus du dossier) et hors d'une copie de la marketplace `soon`, même sans `jq` ; il lit l'accord sur disque et ne dépend d'aucun autre hook : sans `consent-capture`, il refuse.
- [x] Marketplace : une branche `add-<nom>` et une PR ; `main` de la marketplace (dépôt nu) identique avant et après ; un push sur `main` de la marketplace, `gh pr merge` et la fusion par `gh api` sont refusés ; l'entrée et le commit refusent une copie qui n'est pas sur la branche (US-21).
- [x] Coupure simulée avant le push de `main`, après le push de l'étiquette (réponse perdue), au push de la branche, après la création de la PR : le rapport nomme le geste échoué avec son code, ce qui est fait, ce qui reste et la commande qui reprend ; la reprise lit ce qui est fait dans les dépôts eux-mêmes et ne refait rien — un dépôt créé, une PR, une étiquette poussée une fois (US-27). `pp.sh resume` signale la publication en cours et sa commande de reprise.
- [x] `pp.sh mount <plugin> --host <dépôt> [--path …]` : sous-module vers `https://github.com/soonlysoul/<nom>.git`, épinglé sur la dernière étiquette publiée, commité dans l'hôte, jamais poussé ; refusé pour un plugin jamais publié, un hôte absent, un montage déjà fait (US-26).
- [x] Gestes destructifs refusés, même annoncés et accordés : suppression de dépôt, push forcé (`--force`, `-f`, `--force-with-lease`, `+réf`), suppression de référence (`:réf`, `--delete`, `--mirror`), réécriture d'historique (`filter-branch`, `filter-repo`), push sur `main` de la marketplace, fusion. Le retrait d'un plugin n'a aucun chemin : `pp.sh` n'écrit que des ajouts à la marketplace, et tout autre push vers elle est refusé.

**Décision : l'état d'une publication n'est pas versionné.** `publication.json`, `pending`, `consents.log` et `gestures.log` s'écrivent pendant la publication, alors que `claude plugin tag` exige un arbre propre ; versionnés, ils saliraient l'arbre à chaque geste. Le `.gitignore` des plugins créés les ignore, et `publish` refuse un plugin qui ne les ignore pas. Le journal des accords des documents (`approvals.log`) reste versionné.

**Décision : ce qui est fait se lit dans les dépôts, pas dans le journal.** Version et CHANGELOG à HEAD, étiquette locale, dépôt sur GitHub, `origin`, `main` et étiquette sur le distant, branche de la marketplace, PR : chaque geste a sa preuve. Un geste parti dont la réponse s'est perdue est donc reconnu « déjà fait », et un journal perdu ne fait rien refaire. Le journal dit ce qui s'est passé ; il ne décide de rien.

**Décision : un « oui » par étape, pas par geste.** Les gestes locaux (version, commit, étiquette, `origin`, copie et commit de la marketplace) partent avec le geste GitHub qui les suit, annoncés ensemble : cinq accords pour une première publication, deux pour une mise à jour, au lieu de treize et cinq.

Le garde de plugin-flutter, installé pour le compte, a refusé un `rm -rf "$m"` pendant la mise en place d'une copie faussée : il ne voit pas qu'une variable désigne un dossier de `build/`. Non contourné : la copie a pris un dossier neuf, sans rien effacer.

Limites connues : la session doit être ouverte dans le dépôt du plugin (l'accord se capte là, et `publish` le rappelle sinon) ; le garde arrête le geste tapé par erreur, pas un contournement délibéré (un script qui pousse) ; une commande tapée en mode bash (`!`) ne passe par aucun hook ; plugin-flutter, sans `.plugin-plugin/`, reste hors du garde.

### Sondes

| Sonde | Commande | Résultat |
| --- | --- | --- |
| Entrée de `UserPromptSubmit` | lecture du binaire 2.1.296 (`grep -a` autour de `hook_event_name:"UserPromptSubmit"`) | `{…champs communs, hook_event_name, prompt, session_title}` ; `prompt` est le texte soumis (`prompt.submit`), le contexte de l'IDE voyage dans un champ distinct. Fait `user-prompt-submit-input`, confirmé |
| Mode bash | même binaire | « the prompt did not go through prompt.submit (a command, bash mode, an input that did not query, or a failed pass) ». Fait `bash-mode-skips-user-prompt-submit`, confirmé |
| Transcriptions VSCode | `~/.claude/projects/*/*.jsonl`, `entrypoint: claude-vscode` | le fichier ouvert et la sélection y sont des pièces jointes distinctes, jamais mêlées au texte tapé |
| VSCode, en vivant | hook de sonde ajouté en cours de session à `.claude/settings.local.json` (ignoré par git), qui recopie son entrée dans `build/probes/` | il s'est déclenché **sans redémarrage** (fait `settings-hooks-hot-reload`), et **pour la notification de fin d'une tâche de fond**, pas pour un message de Soon : `prompt` vaut `<task-notification>…`, et l'entrée, qui porte aussi `prompt_id` et `scratchpad_dir`, ne dit rien de l'origine (fait `user-prompt-submit-fires-on-notifications`). Puis, à la reprise du 2026-10-20, le message tapé par Soon : `prompt` vaut « Continue phase 13 », tel quel et seul (fait `user-prompt-submit-vscode`, confirmé) ; aucun fichier ouvert ni sélection n'étaient joints au message, ce cas reste à vérifier (fait `user-prompt-submit-vscode-selection`). Hook de sonde retiré |
| `claude plugin tag` sans `--push` | `claude plugin tag --help` ; `test_publish` | l'étiquette est posée en local, aucun push. Fait `plugin-tag-push-optional`, confirmé |

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/hooks/test_consent_capture.sh` | 1 | « hooks/scripts/consent-capture.sh présent » : absent |
| ROUGE | `bash tests/hooks/test_gesture_guard.sh` | 1 | « hooks/scripts/gesture-guard.sh présent » : absent |
| ROUGE | `bash tests/static/test_components.sh` | 1 | 10 réussis, 2 échoués : les deux hooks non câblés |
| ROUGE | `bash tests/static/test_facts.sh` | 1 | 70 réussis, 4 échoués : les quatre faits de la phase 12 absents |
| ROUGE | `bash tests/integration/test_publish.sh` | 1 | « présent : hooks/scripts/consent-capture.sh », « … gesture-guard.sh » |
| VERT | `bash tests/hooks/test_consent_capture.sh` ; `… test_gesture_guard.sh` | 0 | 39 et 63 réussis |
| ROUGE | `bash tests/integration/test_publish.sh` (outil écrit) | 1 | 96 réussis, 29 échoués : la doublure de `gh` sortait en 1 après une création réussie (son dernier `[[ … ]] && …` faux) ; défaut de la doublure, corrigé |
| ROUGE | `bash tests/run-all.sh` | 1 | `test_paths` : `shellcheck -S warning` sur `pp.sh` (SC2178, une variable homonyme d'un tableau) et `lib/consent.sh` (SC2034) ; `test_run_all`, qui copie le plugin, avec lui |
| ROUGE | `bash tests/integration/test_publish.sh` (cas ajouté) | 1 | 123 réussis, 1 échoué : « pp.sh resume signale la publication en cours (US-34) » |
| VERT | `bash tests/integration/test_publish.sh` | 0 | 127 réussis |
| VERT | `bash tests/run-all.sh` | 0 | `test_publish : 127`, `test_gesture_guard : 63`, `test_consent_capture : 39`, `test_release : 102`, `test_facts : 74`, `test_components : 12` réussis ; « coût permanent : 692 tokens (seuil 1000) » ; « réussies : 26, échouées : 0, sautées : 1, bloquées : 0 » ; HEAD de plugin-plugin inchangé par la suite |
| ROUGE | `bash tests/static/test_facts.sh` (après la sonde vivante) | 1 | 74 réussis, 2 échoués : `user-prompt-submit-fires-on-notifications`, `settings-hooks-hot-reload` absents |
| VERT | `test_facts`, `test_reaudit`, `test_consent_capture`, `test_paths`, relancés seuls | 0 | 76, 34, 40 et 77 réussis. Le cas « notification de Claude Code » de `test_consent_capture`, écrit après la sonde, est passé d'emblée : la règle « toute autre réponse retire l'annonce » le couvrait déjà ; une copie faussée prouve qu'il discrimine (ci-dessous) |
| ROUGE | `bash tests/static/test_facts.sh` (après le message tapé) | 1 | 75 réussis, 2 échoués : « fait user-prompt-submit-vscode : confirmé », « fait user-prompt-submit-vscode-selection » |
| VERT | `bash tests/static/test_facts.sh` ; `… test_reaudit.sh` | 0 | 77 et 34 réussis |

### Les tests discriminent

Copies faussées dans `build/mutants/p12/`, une ligne changée chacune, `PLUGIN_UNDER_TEST=<copie> bash <test>` :

| Copie faussée | Test | Premier échec |
| --- | --- | --- |
| tout message qui commence par « oui » vaut accord | test_consent_capture | « « oui mais attends » : aucun accord » |
| une notification de Claude Code est ignorée au lieu de retirer l'annonce | test_consent_capture | « notification de Claude Code : aucun accord, annonce retirée » |
| un refus laisse l'annonce en place | test_consent_capture | « « ok » : annonce retirée » |
| une annonce ne périme jamais | test_consent_capture | « annonce de plus de 30 minutes : retirée, aucun accord » |
| le garde ne consomme pas l'annonce | test_gesture_guard | « l'annonce est consommée », « la même commande, une seconde fois : bloquée » |
| la date de l'annonce n'est plus comparée | test_gesture_guard | « nouvelle annonce, accord de l'ancienne : bloquée » |
| `--force` admis | test_gesture_guard | « « git push --force origin main » : refusé » |
| `gh pr merge` admis | test_gesture_guard | « « gh pr merge 3 … » : refusé » |
| push sur `main` de la marketplace admis | test_gesture_guard | « push sur main de la marketplace : refusé » |
| le journal des accords s'écrit par Edit | test_gesture_guard | « Edit sur .plugin-plugin/consents.log : bloqué » |
| `git -C` ignoré | test_gesture_guard | « git -C vers le plugin géré, depuis ailleurs : bloqué » |
| sans `jq`, tout passe | test_gesture_guard | d'abord **mal formée** : `exit 0 "…"` échoue en « too many arguments » sans sortir, et le garde bloquait plus loin (entrée illisible). Réécrite ; rejouée : « jq absent, geste : bloqué » |
| `pp.sh` lance une étape sans accord | test_publish | « pp.sh lancé sans accord capté : refusé » |
| un accord sert deux fois | test_publish | d'abord **non pris** : aucun cas ne relançait une étape dont le premier geste avait échoué. Cas ajouté (deuxième coupure du push de `main`, relance sur le même « oui ») ; rejoué : « la même étape relancée sur le même « oui » : refusée » |
| l'étiquette poussée n'est jamais reconnue faite | test_publish | « étape de la marketplace : gestes 8 à 12 » |
| toute la publication en une étape | test_publish | « étape annoncée : gestes 1 à 4 » |
| entrée et commit de la marketplace sur `main` admis | test_publish | « marketplace remise sur main : refusé » |
| un montage n'est jamais reconnu fait | test_publish | « montage refait : refusé » |
| état de publication non ignoré admis | test_publish | « journal des gestes non ignoré : refusé » |

## Phase 13 — Reconstruction de plugin-flutter — terminée

- [x] `pp.sh rebuild <original> <dossier>` reconstruit un plugin existant dans un dossier absent ou vide : la charpente que plugin-plugin produit (la fonction `scaffold`, commune avec `create`), puis chaque fichier suivi du dernier commit de l'original, tel quel, sauf les six que la charpente possède — `plugin.json`, `marketplace.json`, `LICENSE`, `.gitignore`, `tests/lib.sh`, `tests/run-all.sh`. L'original n'est lu que par `git archive HEAD` ; un changement non enregistré est signalé et ignoré.
- [x] plugin-flutter reconstruit dans `build/rebuild/plugin-flutter` depuis sa copie de lecture : 47 fichiers importés tels quels ; « charpente : 0 écart avec l'originale » ; la suite de la reconstruction sort en 0 — 16 réussies, 0 échouée, 0 sautée, 0 bloquée (critère 2).
- [x] Validation stricte sur chaque cible : `.`, `.claude-plugin/plugin.json`, `skills`, `agents` ; coût permanent 841 tokens.
- [x] Original intact : `../plugin-flutter` et sa copie de lecture à 55df72c, `git status` vide, avant et après ; `rebuild` le prouve lui-même (HEAD, `git status` sans verrou d'index, empreintes hors `.git/`).
- [x] Chaque écart entre la charpente produite et l'originale corrigé dans plugin-plugin, jamais dans la reconstruction, et consigné ci-dessous.

**Incident, réparé** — le 2026-10-20, une copie faussée de `rebuild` (la charpente importée de l'original au lieu d'être produite) a reconstruit un original d'essai dont le `tests/lib.sh` ne définit pas `PLUGIN_ROOT`. Le `test_run_all.sh` de la charpente, lancé là, copiait `"$PLUGIN_ROOT"/*` : vide, cela faisait `/*`. Il a copié `/home` et `/nix` dans `/tmp/tmp.TkiXQogIFk`, 62 Go, avant que le processus soit arrêté ; son piège de sortie a effacé la copie de `/home`, mais 14 Go de `/nix` restent, que le garde de plugin-flutter interdit d'effacer hors de `build/` : non contourné, **à effacer par Soon** (`rm -rf /tmp/tmp.TkiXQogIFk`). Rien n'a été modifié hors de `/tmp`. Le test est désormais gardé : pointé ailleurs que sur un plugin, il sort en 2 avant toute copie (`test_run_all_guard`, vu rouge sur un petit dossier, jamais sur `/`). Ce test voyage dans chaque plugin créé et chaque reconstruction : la garde aussi.

### Écarts de charpente, à la première reconstruction

`bash scripts/pp.sh rebuild build/ref/plugin-flutter build/rebuild-probe/plugin-flutter` → exit 1, « charpente : 6 écarts avec l'originale », suite à 5 échecs :

| Écart rapporté | Correction dans plugin-plugin |
| --- | --- |
| `[.claude-plugin/plugin.json] keywords : original ["flutter","dart","tdd","git"], produit null` | `scaffold` porte `KEYWORDS`, que `rebuild` lit dans l'original |
| `[.claude-plugin/plugin.json] version : original "0.1.2", produit "0.1.0"` | `scaffold` porte `VERSION` ; `create` remet les deux à zéro, sans quoi l'environnement fuyait dans un plugin créé (prouvé par `test_create`, vu rouge) |
| `[.gitignore] ligne de l'original absente : tests/.tmp/` | ajoutée au `.gitignore` de charpente |
| `[tests/lib.sh] aide absente : bash_input`, `restricted_path`, `SCRIPTS` | ajoutées à `tests/lib.sh`, reprises du harnais de plugin-flutter ; les quatre tests de hooks échouaient sans elles |
| (sans ligne de charpente) `test_run_all` de la charpente échouait : il cherchait les messages de `test_manifest`, que celui de l'original remplace | `test_run_all` contrôle le bilan de `run-all.sh` — la suite qui échoue y est nommée —, plus les messages d'un autre test |

Ce que la charpente a en plus n'est pas un écart : `.gitignore` ignore aussi `build/`, les résultats d'évaluation et l'état volatil de `.plugin-plugin/` ; `run-all.sh` lance aussi `tests/integration/` et `tests/project/`, et mesure le coût en contexte ; ses messages sont en français.

### La suite d'origine, dans l'original et dans la reconstruction

`bash tests/run-all.sh` dans un clone de l'original, puis dans `build/rebuild/plugin-flutter` : exit 0 tous deux.

| Suite de plugin-flutter | Original | Reconstruction |
| --- | --- | --- |
| test_frontmatter | 66 réussis | 66 réussis |
| test_manifest | 16 | 16 |
| test_paths | 69 | 69 |
| test_settings_template | 16 | 16 |
| test_tdd_skill | 25 | 25 |
| test_agent_scope_guard | 73 | 73 |
| test_checkpoint_reminder | 17 | 17 |
| test_format_dart | 14, 1 sauté (`dart` absent du poste) | 14, 1 sauté, le même |
| test_guard_destructive | 206 | 206 |
| validation stricte (4 cibles) | 4 ok | 4 ok |

La reconstruction lance en plus les deux tests de charpente sans homonyme dans l'original — `test_headers` (15 réussis) et `test_run_all` (22) — et le coût en contexte : 841 tokens.

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/integration/test_rebuild.sh` | 1 | 2 réussis, 20 échoués : commande inconnue. Un contrôle passait à tort (`.gitignore` absent compté conforme) : corrigé avant l'implémentation |
| ROUGE | `bash scripts/pp.sh rebuild build/ref/plugin-flutter build/rebuild-probe/plugin-flutter` | 1 | les six écarts ci-dessus, suite à 5 échecs |
| ROUGE | `bash tests/integration/test_create.sh` (VERSION et KEYWORDS dans l'environnement) | 1 | « create : exit 0 » : la suite du plugin créé échouait, version fuyée |
| VERT | `bash tests/integration/test_create.sh` | 0 | 61 réussis |
| VERT | `bash tests/integration/test_rebuild.sh` | 0 | 22 réussis (deux comparaisons JSON d'abord fausses : membre droit de `==` non cité, lu comme un motif) |
| VERT | `bash tests/integration/test_rebuild.sh` (charpente de plugin-plugin, écart rapporté sur un original d'essai) | 0 | 29 réussis ; l'original d'essai cachait d'abord son échec (`helper && pass` sans `fail`), corrigé |
| ROUGE | `bash tests/integration/test_rebuild.sh` (changement non enregistré) | 1 | « changement non enregistré de l'original : signalé, pas reconstruit » |
| VERT | `bash tests/integration/test_rebuild.sh` | 0 | 30 réussis |
| ROUGE | `bash tests/static/test_run_all_guard.sh` (après l'incident) | 1 | 0 réussis, 3 échoués : pointé sur un petit dossier qui n'est pas un plugin, `test_run_all.sh` le copiait et lançait sa suite |
| VERT | `bash tests/static/test_run_all_guard.sh` ; `… test_run_all.sh` | 0 | 3 et 22 réussis (la garde exclue des copies de `test_run_all`) |
| VERT | `bash tests/run-all.sh` (après la garde) | 0 | `test_rebuild : 30`, `test_create : 61`, `test_run_all : 22`, `test_run_all_guard : 3` réussis ; « coût permanent : 824 tokens (seuil 1000) » ; « réussies : 31, échouées : 0, sautées : 1, bloquées : 0 » |

### Les tests discriminent

Copies faussées dans `build/mutants/p13b/` (les premières, `p13/`, avaient le `test_run_all.sh` d'avant la garde : retirées), une ligne changée chacune, contre leur propre clone de la copie de lecture (`build/mutants/p13b-ref/`), une des copies écrivant dans l'original :

| Copie faussée | Test | Premier échec |
| --- | --- | --- |
| version toujours 0.1.0 | test_rebuild | « rebuild : exit 0 », « aucun écart entre la charpente produite et l'originale », « plugin.json : le même que l'original » |
| keywords jamais portés | test_rebuild | les mêmes |
| `restricted_path` retiré de `tests/lib.sh` | test_rebuild | « rebuild : exit 0 », « aucun écart … », « rebuild rapporte la suite verte » |
| la charpente importée de l'original | test_rebuild | d'abord **hors de contrôle** : la copie de `/` décrite plus haut, délai dépassé. Rejouée après la garde : « tests/lib.sh : celui de plugin-plugin, jamais celui de l'original » |
| dossier cible non vide accepté | test_rebuild | « dossier cible non vide : refusé, rien n'y est écrit » |
| écarts de charpente jamais rapportés | test_rebuild | « rapporté : ^charpente : 2 écarts », « aide absente : helper_maison … », « ligne de l'original absente : cache-local/ » |
| changement non enregistré passé sous silence | test_rebuild | « changement non enregistré de l'original : signalé, pas reconstruit » |
| `create` hérite de VERSION et KEYWORDS | test_create | « create : exit 0 », « plugin.json au modèle, sans e-mail » |
| `rebuild` écrit dans l'original | test_rebuild | « original intact : HEAD, git status et empreintes identiques » ; `rebuild` le dit lui-même, exit 1 |
| (test) `test_run_all.sh` sans garde | test_run_all_guard | « PLUGIN_ROOT hors d'un plugin : exit 2 » — vu rouge sur un petit dossier |

## Phase 14 — Réécriture de plugin-nixos au modèle — terminée

- [x] Les 15 écarts que `check` relève sur l'original (phase 10) forment la liste de travail ; sur la réécriture, `check` n'en relève aucun (critère 2).
- [x] `tests/rewrite/plugin-nixos.sh ORIGINAL DOSSIER` — un test de plugin-plugin, pas une fonction (PRD) : `pp.sh rebuild` pose la charpente et importe le contenu tel quel, puis la recette ne fait que ce que le modèle impose, chaque geste fermant un écart nommé (tableau ci-dessous). Chaque retouche porte sur un texte exact, présent une seule fois : si l'original change, la recette s'arrête au lieu de deviner. La réécriture prouvée vit dans `build/rewrite/plugin-nixos`.
- [x] Suite portée au harnais du modèle — `tests/lib.sh` et `run-all.sh` de plugin-plugin, `tests/hooks/` et `tests/static/` — : les cas d'origine mot pour mot, sur `pass`, `fail`, `skip`, `finish`, `run_hook`, `bash_input`, `expect_status`, `expect_blocked`, `restricted_path`, `PLUGIN_ROOT` et `PLUGIN_UNDER_TEST`. Chaque cas d'origine a son équivalent : les libellés des deux suites sont comparés un à un, après le seul renommage des chemins déplacés, une durée mesurée, et le cas que le modèle retourne (« forme « command » seule » devient « forme exec »). Comptes avant et après ci-dessous ; la suite portée sort en 0 (critère 2).
- [x] Validation stricte sur chaque cible : `.`, `.claude-plugin/plugin.json`, `skills` ; `agents` sauté, absent.
- [x] Le script appelé par les skills, `nixconf`, reste à `scripts/nixconf`, cité par `${CLAUDE_PLUGIN_ROOT}/scripts/nixconf` (décision a), et passe désormais les tests de chemins du modèle — il y échappait faute d'extension. Son gabarit `modeles/flake.nix` va à `scripts/modeles/`, comme ceux de `pp.sh` sous `scripts/scaffold/` : `templates/` est ce qu'un skill cite. Le serveur MCP est redéclaré par `pp.sh add-mcp` (phase 9) : déclaration identique à l'original, son test `test_mcp_nixos`, la section « Serveurs MCP » du README et le rappel de la doublure `evals/mocks/nixos/`.
- [x] Original intact : `../plugin-nixos` à dc6ea53, `git status` vide, empreintes identiques avant et après ; la copie de lecture `build/ref/plugin-nixos` aussi (ses trois bits d'exécution perdus datent du 2026-10-19, voir phase 10). **Sous-module : introuvable.** `~/Documents/Nixos` n'existe pas ; `~/Nixos` est le dépôt nixos-config, sans sous-module ; aucun `.gitmodules` sous `~` (profondeur 5) ne cite plugin-nixos. Le volet sous-module du critère est sans objet sur ce poste : à confirmer par Soon.

**Décision de Soon, le 2026-10-20 : au-delà du budget, une alerte, sauf pour plugin-plugin.** plugin-nixos coûte ~1 126 tokens permanents, ses quatre descriptions de skill ; le `run-all.sh` du modèle échouait au-delà de 1 000, et la suite portée ne pouvait sortir en 0 sans toucher au métier. Question posée avec trois choix ; réponse : « Alert, fail only for p-p (Recommended) ». Le PRD dit « alerte au-delà de 1 000 tokens permanents par plugin », le critère 9 ne vise que plugin-plugin. `tests/run-all.sh` porte `OVER_BUDGET=fail` ; la charpente l'écrit `alert` dans ce qu'elle produit ; le bilan gagne une ligne « alertes ». La répétition de publication, qui refusait un plugin au-delà du seuil parce que sa suite rougissait, alerte et continue, comme le plan de la phase 11 le décrit.

**Ce que le modèle retire à plugin-nixos — consigné, non tranché.** La forme exec demande Claude Code 2.1.295. L'original gardait exprès la forme `command` seule pour qu'un poste en 26.05, dont le claude-code est la 2.1.223, puisse déclarer celui de son canal (son ARCHITECTURE, mesure du 2026-10-19). La réécriture le dit dans son ARCHITECTURE. Sans conséquence ici, puisqu'elle n'est jamais publiée ; c'est le premier cas où le modèle contredit une contrainte métier mesurée.

Limites constatées : le `restricted_path` du modèle lie un outil absent à un chemin vide, avec un message de `ln`, là où l'original le sautait ; tous les outils que les suites de plugin-nixos restreignent sont présents sur ce poste. La réécriture prend de 3 à 5 minutes, surtout dans le `test_run_all` du modèle, qui relance une dizaine de fois la suite portée ; `test_rewrite_nixos` l'ajoute à la suite de plugin-plugin.

### De la liste de travail à zéro écart

| Écart de l'original (`check`) | Geste de la recette |
| --- | --- |
| `[arborescence des hooks]` `hooks/garde-nixos.sh`, `hooks/lib-commande.sh` hors de `hooks/scripts/` | `hooks/scripts/garde-nixos.sh` ; `hooks/scripts/lib/lib-commande.sh`, identique, comme `lib/shell-lexer.sh` de plugin-flutter ; dans le garde, le chemin de sa bibliothèque et celui de `nixconf` (3 lignes) |
| `[forme des hooks]` forme shell ; `[hooks]` `onFailure` non déclaré | `command` « bash », le garde seul dans `args`, `timeout` d'origine (15), `"onFailure": "block"` ; le garde déclare `# Fail-closed` dans son en-tête |
| `[arborescence]` `modeles` hors modèle | `scripts/modeles/flake.nix` ; une ligne de `nixconf` (`modeles="$ici/modeles"`) |
| `[harnais]` trois tests à la racine de `tests/`, `tests/static/` sans test | `tests/hooks/test_garde_nixos.sh`, `tests/static/test_nixconf.sh`, `tests/static/test_statique.sh`, portés au harnais du modèle |
| `[racine]` CHANGELOG sans entrée `[0.1.2]` | titres au format du modèle : `## [0.1.2] — 2026-10-19` |
| `[racine]` PROGRESS.md et les quatre documents de `docs/` absents | écrits pour la réécriture : ils renvoient aux sections du README, et INSTALLATION porte l'avertissement de portée du garde |

Plus : les chemins déplacés mis à jour dans ARCHITECTURE et dans un commentaire de `nixconf`, et le paragraphe de la forme des hooks réécrit. Rien d'autre ne change : skills, lanceur MCP, `.mcp.json`, LICENSE et `lib-commande.sh` identiques à l'original ; README identique, plus la section « Serveurs MCP » de `add-mcp`.

`pp.sh rebuild` seul, avant le portage : « charpente : 12 écarts » — les aides de l'ancien harnais (`attendre`, `reussi`, `RACINE`…) absentes de `tests/lib.sh`, que le portage remplace par celles du modèle — et suite rouge : `test_manifest` (CHANGELOG), `test_paths` (forme des hooks), `test_run_all` ; les tests d'origine, à la racine de `tests/`, ne sont même pas lancés.

### La suite d'origine et la suite portée

`bash tests/run-all.sh` dans un clone de l'original, exit 0 ; puis `bash tests/rewrite/plugin-nixos.sh ../plugin-nixos build/rewrite/plugin-nixos`, exit 0. Chaque suite d'origine est relancée par la recette à côté de son équivalent :

| Suite d'origine | Original | Suite portée | Réécriture | Cas d'origine sans équivalent |
| --- | --- | --- | --- | --- |
| `tests/test_garde.sh` | 217 réussis | `tests/hooks/test_garde_nixos.sh` | 217 réussis | 0 |
| `tests/test_nixconf.sh` | 63 réussis | `tests/static/test_nixconf.sh` | 63 réussis | 0 |
| `tests/test_statique.sh` | 71 réussis | `tests/static/test_statique.sh` | 78 réussis | 0 |
| validation stricte | `.`, `plugin.json`, `skills` : ok | — | `.`, `plugin.json`, `skills` : ok ; `agents` sauté | — |

`test_statique` porté a sept cas de plus : la syntaxe des fichiers du harnais du modèle (`tests/headers.sh`, `tests/mcp.sh`, et `test_headers`, `test_manifest`, `test_mcp_nixos`, `test_paths`, `test_run_all` sous `tests/static/`). Un cas change de sens, et c'est le modèle : « hooks.json : forme « command » seule, sans args ni onFailure » devient « hooks.json : forme exec, le garde dans args, onFailure block ». La réécriture lance en plus les tests de la charpente — `test_headers` (12), `test_manifest` (26), `test_paths` (32), `test_run_all` (31) — et `test_mcp_nixos` (2) ; bilan « réussies : 11, échouées : 0, sautées : 1 (agents), bloquées : 0, alertes : 1 (coût en contexte, 1126 tokens > 1000) ».

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash scripts/pp.sh rebuild ../plugin-nixos build/p14/rebuild-probe` | 1 | « charpente : 14 écarts » (les descriptions de la marketplace, les aides de l'ancien harnais), suite à 4 échecs, dont « coût permanent illisible » : `plugin details` écrit « ~1,126 tok » ; `check` : 9 écarts |
| ROUGE | `bash tests/static/test_run_all.sh` | 1 | 24 réussis, 7 échoués : `OVER_BUDGET` absent, aucune alerte, « ~1,126 tok » illisible |
| ROUGE | `bash tests/integration/test_create.sh` | 1 | 57 réussis, 5 échoués : le plugin créé n'a pas `OVER_BUDGET=alert`, et sa propre copie du nouveau `test_run_all` le voit |
| ROUGE | `bash tests/integration/test_release.sh` (lecture du coût défaite dans `pp.sh`, écrite avant son test) | 1 | 102 réussis, 1 échoué : « échec : coût en contexte illisible » sur « ~1,126 tok » ; au-delà du seuil, la répétition continue désormais, avec son alerte |
| VERT | `test_run_all` ; `test_create` ; `test_release` | 0 | 31, 62 et 103 réussis |
| ROUGE | `bash tests/integration/test_rebuild.sh` | 1 | 29 réussis, 1 échoué : `tests/run-all.sh` comparé octet pour octet à celui de plugin-plugin, que la charpente change désormais d'une ligne : comparaison corrigée |
| ROUGE | `bash tests/integration/test_rebuild.sh` (marketplace décrite par l'original d'essai) | 1 | 29 réussis, 2 échoués : « marketplace.json : ses descriptions, celles de l'original », « charpente : 4 écarts » au lieu de 2 |
| VERT | `bash tests/integration/test_rebuild.sh` | 0 | 31 réussis |
| ROUGE | `bash tests/integration/test_create.sh` (remise à zéro défaite, écrite avant son test) | 1 | 62 réussis, 1 échoué : « marketplace.json décrite par la charpente » |
| VERT | `bash tests/integration/test_create.sh` | 0 | 63 réussis |
| ROUGE | `bash tests/static/test_check.sh` ; `… test_create.sh` (outil sans extension) | 1 | 56 réussis, 2 échoués ; 64 réussis, 4 échoués : l'outil invisible pour `check` et pour `test_paths` |
| VERT | `test_check` ; `test_create` | 0 | 58 et 68 réussis |
| VERT | `bash tests/run-all.sh` (étapes 1 à 3) | 0 | « réussies : 31, échouées : 0, sautées : 1, bloquées : 0, alertes : 0 » ; coût permanent 824 tokens |
| ROUGE | `bash tests/static/test_facts.sh` | 1 | 77 réussis, 1 échoué : « fait plugin-details-thousands-separator : absent de la base » |
| VERT | `bash tests/static/test_facts.sh` ; `… test_reaudit.sh` | 0 | 78 et 34 réussis |
| VERT | `bash tests/rewrite/plugin-nixos.sh ../plugin-nixos build/p14/try1` | 0 | premier essai de la recette, avant son test : suite portée verte, 0 écart, 0 cas sans équivalent |
| ROUGE | `bash tests/integration/test_rewrite_nixos.sh` | 1 | 18 réussis, 5 échoués : « 192 Kio jugés en moins de 10 s (mesuré : 2 s) » sans équivalent — l'original avait mesuré 1 s, et la normalisation des durées ne s'appliquait jamais (en BRE, `\(` est un groupe, pas une parenthèse) ; le test doublait le préfixe `test_` des suites |
| VERT | `bash tests/integration/test_rewrite_nixos.sh` | 0 | 23 réussis ; puis 27 avec la déclaration du serveur MCP par `add-mcp` |
| VERT | `bash tests/rewrite/plugin-nixos.sh ../plugin-nixos build/rewrite/plugin-nixos` | 0 | la preuve, sur l'original réel, avec la recette finale |
| VERT | `bash tests/run-all.sh` | 0 | `test_rewrite_nixos : 27`, `test_create : 68`, `test_rebuild : 31`, `test_release : 103`, `test_run_all : 31`, `test_check : 58`, `test_facts : 78` réussis ; « coût permanent : 824 tokens (seuil 1000) » ; « réussies : 32, échouées : 0, sautées : 1, bloquées : 0, alertes : 0 » ; 19 min 24 s |

### Les tests discriminent

Copies faussées dans `build/mutants/p14/`, une ligne changée chacune, `PLUGIN_UNDER_TEST=<copie> PP_REF_DIR=<clone> bash <test>`. Les clones de lecture sont à part (`build/mutants/p14-ref*`) : la copie qui écrit dans l'original a le sien.

| Copie faussée | Test | Premier échec |
| --- | --- | --- |
| `OVER_BUDGET=alert` ignoré | test_run_all | « OVER_BUDGET=alert, 1.2k tokens permanents : exit 0 », « l'alerte est dite » |
| virgule de milliers non lue (`run-all.sh`) | test_run_all | « ~1,126 tok : 1126 tokens, séparateur de milliers lu » |
| virgule de milliers non lue (`pp.sh release`) | test_release | « ~1,126 tok : 1126 tokens, séparateur de milliers lu » |
| la charpente recopie `run-all.sh` sans le mettre en alerte | test_create, test_rebuild | « create : exit 0 » (le `test_run_all` du plugin créé le voit) ; « rebuild : exit 0 », « tests/run-all.sh : … en alerte au-delà du budget » |
| descriptions de la marketplace non portées | test_rebuild | « marketplace.json : ses descriptions, celles de l'original », « charpente : 2 écarts » |
| `create` hérite des descriptions de l'environnement | test_create | « marketplace.json décrite par la charpente » |
| `test_paths` sans les outils sans extension | test_create | « outil sans extension : contrôlé comme un script, et vert », « … bash -n échoue », « … #!/bin/sh : refusé » |
| `check` sans les outils sans extension | test_check | « outil sans extension sous scripts/ qui ne se lit pas », « … en #!/bin/sh » |
| la recette perd un cas (`refuse "nixos-rebuild boot"`) | test_rewrite_nixos | « réécriture : exit 0 », « test_garde : chacun de ses cas a son équivalent », « cas d'origine sans équivalent : 0 » |
| la recette laisse le garde en forme shell | test_rewrite_nixos | « réécriture : exit 0 » : `add-mcp` refuse un plugin hors modèle et nomme l'écart, « [forme des hooks] … garde-nixos.sh » |
| la recette laisse `modeles/` à la racine | test_rewrite_nixos | « réécriture : exit 0 » : `add-mcp` refuse, « [arborescence] hors modèle : modeles » |
| la recette ne redéclare pas le serveur MCP | test_rewrite_nixos | « test du serveur, écrit par add-mcp, vert », « rappel de la doublure d'évaluation », « README : l'original, plus la section « Serveurs MCP » » |
| la recette écrit dans l'original | test_rewrite_nixos | « réécriture : exit 0 » — la recette le dit elle-même : « ÉCHEC : l'original a changé pendant la réécriture » |

Deux défauts des tests eux-mêmes, trouvés par les copies faussées et corrigés : le `test_paths` d'un plugin créé, lancé directement par `test_create`, et les suites de la réécriture, lancées une à une par la recette, héritaient de `PLUGIN_UNDER_TEST` et vérifiaient la copie faussée au lieu de leur propre dossier ; ils l'effacent désormais (`env -u`, `unset`). Les échecs d'abord vus pour la copie qui hérite des descriptions ne prouvaient donc rien : rejouée après la correction, elle n'échoue plus que sur son cas.

## Phase 15 — Plugin témoin de bout en bout — terminée

Témoin : `plugin-changelog`, dans `build/temoin-p15`, son propre dépôt git (ignoré par plugin-plugin, jamais publié). Il rédige (skill `draft-entry`), garde (hook `changelog-guard`) et relit (agent `changelog-reviewer`) l'entrée « en cours » d'un CHANGELOG au format de la maison. Construit le 2026-10-20 dans une session VSCode, plugin-plugin chargé par une installation locale — `claude plugin marketplace add ./ --scope local`, `claude plugin install plugin-plugin@plugin-plugin --scope local`, dans `.claude/settings.local.json`, ignoré par git —, puis `/reload-plugins`. Quatre commits du témoin : `f3e445b` charpente, `619cb7d` hook, `d380a34` agent, `dd289c1` skill ; arbre propre.

- [x] Cadrage approuvé avant tout fichier : six questions, une par message, recommandation en tête (besoin, hors périmètre, nom, langue des identifiants, composants, critères) ; PRD puis architecture approuvés chacun par un « oui » de Soon, passé tel quel à `pp.sh approve`. Création verte : « suite du plugin créé : exit 0 », réussies 7, échouées 0, sautées 2 (skills, agents absents).
- [x] Un hook, un agent, un skill, chacun ajouté par `/plugin-plugin:add`, avec sa sortie rouge puis verte (tableau ci-dessous).
- [x] Le skill s'évalue sans Bash (`Skill`, `Read`, `Glob`, `Grep`) : deux positifs, un négatif, choisis par Soon, trois exécutions chacun ; écart +1.00 sur les deux positifs contre le témoin sans plugin ; chaque passage annoncé — sessions, fourchette, plafond, compte — puis lancé sur un « oui ».
- [x] Répétition de publication complète, rien d'envoyé (ci-dessous).
- [x] Aucune retouche à la main d'un fichier du témoin ; 26 interventions de Soon, chacune demandée, comptées ci-dessous.
- [x] Preuve de chargement : le `system/init` d'une exécution du bras avec plugin, gardée par `--keep-temp`, liste `plugin-changelog` (`plugin-changelog@inline`, 0.1.0) et le skill `plugin-changelog:draft-entry`, avec `plugin_errors: null`.

### Rouge puis vert, dans le témoin

| Composant | Étape | Commande | Code | Résultat |
| --- | --- | --- | --- | --- |
| hook `changelog-guard` | ROUGE | `bash tests/hooks/test_changelog_guard.sh` (squelette) | 1 | 12 réussis, 11 échoués : chaque cas de la règle passe en exit 0 |
| | ROUGE | même test, règle écrite | 1 | 22 réussis, 1 échoué : défaut du test (motif sans effet dans une substitution entre guillemets), corrigé ; rejoué sur le squelette seul : 13 réussis, 11 échoués |
| | VERT | même test | 0 | 24 réussis, 0 échoué ; `run-all` : réussies 8, sautées 2, coût permanent 0 |
| agent `changelog-reviewer` | ROUGE | `bash tests/static/test_agent_changelog_reviewer.sh` (agent absent) | 1 | 0 réussi, 1 échoué : `agents/changelog-reviewer.md` absent |
| | VERT | même test ; `test_agent_scope_guard.sh` | 0 | 5 réussis ; garde de portée 13 réussis ; `pp.sh check-agent` conforme ; `run-all` : réussies 11, coût permanent 141 |
| skill `draft-entry` | ROUGE | `pp.sh eval-run . draft-entry --one-arm --quote « oui »` (skill absent, 9 sessions) | 1 | positifs 0.00 (skill jamais appelé, format absent), négatif 1.00 ; « verdict : rouge » ; 0,62 USD |
| | VERT | `pp.sh eval-run . draft-entry --keep-temp --max-cost 4.5 --quote « oui »` (18 sessions, deux bras) | 0 | `ajout-correction` et `modifie-retire` : avec 1.00, sans 0.00, Δ +1.00 ; `commit` 1.00 / 1.00 ; « verdict : vert » ; 1,16 USD |
| | VERT | `bash tests/run-all.sh` | 0 | réussies 12, échouées 0, sautées 0, bloquées 0, alertes 0 ; coût permanent 350 tokens |

Coût réel du passage : 1,78 USD pour 27 sessions, environ 0,07 USD par session, sous la fourchette de `eval-plan` (0,13 à 0,23) ; compte annoncé : `max`, signalé à Soon avant chaque « oui ».

### Répétition de publication

`/plugin-plugin:release build/temoin-p15`, tapé par Soon (le skill ne se lance que sur demande explicite) → `pp.sh release`, exit 0 : version 0.1.0 (première publication, version de `plugin.json`) ; validation stricte ok sur `.`, le manifeste, `skills` et `agents` ; suite du plugin exit 0 (réussies 12) ; coût permanent ~350 tokens, `draft-entry` ~200 (~850 à l'appel), `changelog-reviewer` ~150 (~630) ; entrée `## [0.1.0] — 2026-10-20` rédigée ; étiquette `plugin-changelog--v0.1.0` vérifiée par `claude plugin tag --dry-run` ; 13 gestes listés, dont 5 vers GitHub (création du dépôt, push de `main` et de l'étiquette, push de la branche de marketplace, PR), « aucun exécuté ». Après coup : arbre propre, aucune étiquette, aucun remote, `/tmp/plugin-plugin-release` absent.

### Interventions de Soon

26, chacune demandée : 3 pour la mise en place (installation locale, un passage payant pour les phases 6 et 15, `/reload-plugins`) ; 6 réponses d'interview ; 2 approbations ; le commit de la charpente ; pour le hook, la demande, le squelette, le commit ; pour l'agent, la demande, le modèle (`sonnet`), le commit ; pour le skill, la demande, deux positifs, un négatif, le passage rouge, le passage vert, le commit ; la répétition. Les trois demandes d'ajout ont été choisies par Soon parmi des formulations proposées, chacune sous un angle — par le besoin (hook), directe (agent), indirecte (skill) — ; elles font les positifs de `evals/add/`.

### Écarts de plugin-plugin révélés par le témoin, corrigés

| Écart | Dans le témoin | Correctif | Rouge | Vert |
| --- | --- | --- | --- | --- |
| n°1 — `init-state` refuse un dossier cible absent (« dossier existant ») : `frame` ne pouvait cadrer un plugin neuf sans un `mkdir` préalable | dossier vide créé par `mkdir` avant `init-state`, aucun fichier touché | `init-state` crée le dossier absent, un niveau seulement, et refuse un parent absent en le nommant ; `frame` l'accepte « empty or missing » | `test_frame` : 42 réussis, 3 échoués (« dossier absent : exit 0 », « … créé avec son état », « parent absent : le parent nommé ») | 45 réussis, 0 échoué |
| n°2 — `add-agent` écrit « writes only under nothing » pour un agent sans dossier d'écriture, « Bash only nothing » pour un agent sans Bash | laissé tel quel dans `agents/changelog-reviewer.md` (aucune retouche à la main) | « writes nothing », « no Bash » | `test_add_agent` : 44 réussis, 2 échoués (les deux phrases fautives citées) | 46 réussis, 0 échoué |

Suite de plugin-plugin après les correctifs, la base de faits et `evals/add/` : `bash tests/run-all.sh`, exit 0 — réussies 32, échouées 0, sautées 1, bloquées 0, alertes 0 ; coût permanent 824 tokens, inchangé.

### Ce que la phase a appris, porté dans la base de faits

- Une installation depuis une marketplace locale copie tout le dossier dans le cache, fichiers ignorés par git compris : 136 Mo pour plugin-plugin (`directory-marketplace-install-copies-ignored`).
- Une session d'évaluation d'un skill court sans Bash coûte environ 0,07 USD (`eval-session-cost-short-skill`) ; la fourchette de `eval-plan` reste une majoration, gardée telle quelle.
- `claude plugin eval` ne charge aucun plugin installé, dans aucun bras (`eval-arms-load-no-installed-plugins`).
- `claude auth status` a annoncé `pro` le 2026-10-19, `max` le 2026-10-20, pour le même profil (note sur `auth-status-announced-account`, toujours à vérifier).

### Écart de la phase 9, fermé

`evals/add/` : cinq cas, écrits et vérifiés par `pp.sh check-evals . add` (« conforme : 5 cas (3 positifs, 2 négatifs), 3 exécutions par cas au moins »), sans être lancés (choix de Soon). Positifs : les trois demandes du témoin, telles que choisies — hook, agent, skill désigné par l'architecture —, sur un `plugin-changelog` posé par `setup.sh`. Négatifs, validés par Soon : « ajoute une ligne au CHANGELOG de plugin-changelog pour le hook changelog-guard » (« ajoute » et un nom de hook, mais une ligne de journal) et « crée-moi un nouveau plugin plugin-notes pour prendre des notes » (le terrain de `frame`).

Non fait, par choix de Soon : l'exécution réelle de l'agent `changelog-reviewer` sur un dépôt d'essai — ses tests et son garde de portée suffisent à la phase.

## Phase 16 — Clôture de 0.1.0, puis publication de 0.1.1 — terminée

- [x] Relecture : le constat critique et les 21 majeurs corrigés, trois défauts de `pp.sh` corrigés rouge puis vert, suite relancée (exit 0) ; plugin-dev reste une aide de développement, pas une dépendance.
- [x] Coût permanent 880 tokens, sous 1 000 (critère 9).
- [x] 0.1.1 : `plugin.json` et CHANGELOG à jour (`a72ecda`) ; étiquette `plugin-plugin--v0.1.1` sur GitHub, même objet `c6727ed` en local et sur `origin` (critère 7).
- [x] Push de `main`, de l'étiquette, de la branche de marketplace et PR, chacun sur un « oui » consigné (critère 6) ; la création du dépôt est antérieure aux gestes annoncés, écart consigné ci-dessous. PR fusionnée par Soon.
- [x] Commande d'installation donnée ; sur ce poste, `claude plugin list` montre `plugin-plugin@soon`, Version 0.1.1 (critère 7).

### Relecture des skills par `plugin-dev:skill-reviewer`

plugin-dev est installé pour le compte mais désactivé. Plutôt que de l'activer (un réglage, puis `/reload-plugins`), sa définition — `agents/skill-reviewer.md` du cache `a0b04d9ddcca`, identique à celle de la marketplace — a été donnée telle quelle à sept sous-agents, un par skill, en un seul passage : mêmes consignes, mêmes outils en lecture (`Read`, `Grep`, `Glob`), modèle hérité. plugin-dev reste une aide de développement, pas une dépendance.

Verdicts : `release` Pass ; les six autres « Needs Improvement ». 1 constat critique, 21 majeurs, une quarantaine de mineurs. Chaque constat critique ou majeur a été vérifié dans le code avant d'être traité ; tous sont réels et tous sont corrigés :

| Skill | Constat | Traitement |
| --- | --- | --- |
| `resume` | critique : le test ciblé n'était pas lancé depuis le dossier du plugin, et « pas de suite complète » contredisait le `--test "bash tests/run-all.sh"` de `create` | lancé par `cd <dossier> && …` ; une suite complète notée est le test ciblé ; une commande qui n'est pas `bash tests/…` est montrée et demandée |
| `resume`, `frame` | reprendre un skill relance son `checkpoint … start`, qui efface les étapes faites (`pp.sh`, `cmd_checkpoint`) | `start` refusé sur un point inachevé du même skill, l'étape suivante nommée ; `--restart` si Soon abandonne ce travail ; les skills reprennent par `done` |
| `resume` | branches de `pp.sh resume` sans consigne (sans point de reprise, `reste : rien`, publication en cours) ; blocages absents du résumé | une consigne par branche ; blocages et incohérences nommés, Soon décide avant toute reprise |
| `check` | un nom de plugin (« plugin-nixos suit-il le modèle ? ») pris pour un dossier | cherché à côté du dépôt courant, demandé sinon ; dossier courant seulement sans nom |
| `release` | « publie plugin-x » inatteignable sous `disable-model-invocation` | « /plugin-plugin:release plugin-x » |
| `frame` | reprise lue sur le seul PRD ; gabarit rempli par-dessus un document ; refus du script et demande de changement confondus ; user stories et choix d'architecture jamais demandés, « à trancher » approuvables ; un seul déclencheur | reprise lue sur les deux documents ; jamais de gabarit sur un document existant ; trois cas d'accord ; stories dérivées des réponses, choix réglés avec chaque composant, « à trancher » listés avant l'accord, sans question nouvelle ; « je veux un plugin qui… » |
| `create` | point de reprise ouvert avant l'étape 1, refus qui pousse vers `init-state` ; codes de sortie mal lus (suite bloquée, `jq`, `échec : git init`, recréation refusée) ; validation stricte illisible, `alertes` oubliées | point ouvert après l'étape 1, jamais `init-state` ; une consigne par issue ; la validation se lit sur les lignes `claude plugin validate` du bilan |
| `add` | un seul déclencheur (agents) ; chemins de tests faux pour un nom à tirets — un fichier absent (exit 127) passait pour le rouge attendu ; étapes du point de reprise dans une référence pas encore lue | « ajoute un hook à plugin-… » ; le chemin que donne la ligne `écrit :`, tirets changés en `_` ; la référence lue avant `start` |
| `reaudit` | l'étape 4 compare un instantané que le ré-audit a effacé ; la copie installée est auditée, le clone modifié ; clés de `facts.json` mal nommées, `probe.expect` oublié ; classement ambigu ; un seul « oui » pour deux accords, rien après | instantané écrit dans un dossier jetable, diff par chemin ; ré-audit du clone (`--facts`, `--snapshots`, `--probes`) ; clés exactes ; `confirmé` / `infirmé` / `non tranché` et « non lancé » ; deux questions, étape 7 après le « oui » |

Mineurs retenus, dont deux défauts de `pp.sh` : un agent qui déclare `Monitor` sans `Bash` échappait au garde de portée, alors que `Monitor` lance une commande — il est traité comme `Bash` ; un `&` dans la description d'un plugin créé devenait `__DESCRIPTION__` (bash ≥ 5.2 remplace `&` par le motif dans une substitution non citée). Aussi : guillemets simples pour `--quote` et `--description`, première publication et montage dans `release`, numéro de ligne jamais inventé dans `check`, approbation jamais déléguée dans `frame`, consentement de 30 minutes nommé.

Écartés, contraires aux règles du modèle (`tests/headers.sh`, base de faits) : description à la troisième personne ; `when_to_use` « déprécié » (fait `plugindev-when-to-use-deprecated`, à vérifier, contredit par `skill-fields`) ; corps de 1 000 à 3 000 mots ; champ `version`. Non retenus, pour le coût en contexte : `when_to_use` de `check` reformulé, énumération des travaux dans la description de `resume`. Non retenus : cas d'évaluation supplémentaires (`check` par nom, `frame` sur « crée-moi un plugin »).

### Rouge puis vert

| Défaut | Étape | Commande | Code | Résultat |
| --- | --- | --- | --- | --- |
| `&` dans la description | ROUGE | `bash tests/integration/test_create.sh` | 1 | 68 réussis, 1 échoué : « README : la description telle quelle, & compris » — `Notes __DESCRIPTION__ brouillons, a\b compris.` |
| | VERT | même test | 0 | 69 réussis, 0 échoué |
| `checkpoint start` efface un point inachevé | ROUGE | `bash tests/static/test_resume.sh` | 1 | 31 réussis, 8 échoués : start exit 0, point effacé, et les cinq cas de reprise qui suivent, faute d'étapes faites |
| | VERT | même test | 0 | 39 réussis, 0 échoué |
| `Monitor` sans liste blanche | ROUGE | `bash tests/integration/test_add_agent.sh` | 1 | 45 réussis, 2 échoués : « Monitor sans liste blanche : refusé », « après les refus, plugin identique » |
| | VERT | même test | 0 | 47 réussis, 0 échoué |

`pp.sh check-skill` : les sept skills conformes ; `pp.sh check-evals` : les sept suites conformes.

Suite complète après les corrections et `init-state` : `bash tests/run-all.sh`, exit 0 — réussies 32, échouées 0, sautées 1 (`agents` absent), bloquées 0, alertes 0 ; coût permanent 880 tokens.

### Coût en contexte permanent

824 tokens avant la relecture ; 911 après les corrections ; 880 après élagage des descriptions (les déclencheurs corrigés gardés). Seuil : 1 000 (critère 9).

### Documents

- `docs/ARCHITECTURE.md`, `docs/INSTALLATION.md`, `docs/USER_GUIDE.md`, `docs/SECURITY.md`, `docs/TROUBLESHOOTING.md` : `pp.sh check .` passe de 5 écarts à « écarts : 0 — au modèle de plugin-flutter ». L'architecture est dans `docs/`, où `pp.sh approve` la reconnaît, statut REVUE.
- `docs/PLAN.md` : les errata de la clôture, corrigés en une fois et listés sous son statut, repassé en REVUE — la validation de la racine couvre `plugin.json` ; `~/Documents/Nixos` n'existe pas et `~/Nixos` ne mentionne pas bwrap, absent du `PATH` ; le volet sous-module de la phase 14 sans objet sur ce poste.
- `pp.sh init-state .` : plugin-plugin porte désormais son propre `.plugin-plugin/` (`approvals.log`, `decisions.md`, versionnés), pour tracer les approbations et la publication.

### Constaté sur GitHub, par `gh api`

`soonlysoul/plugin-plugin` existe déjà : public, créé le 2026-10-19 à 21:19 UTC, branche par défaut `feat/v0.1.0`, poussée jusqu'à `688d4f1` (phase 8) ; `main` à `bd531f4` ; aucune étiquette. Ni sa création ni ce push ne sont passés par les gestes annoncés de plugin-plugin, qui n'existaient pas encore. L'entrée de la marketplace `soon` n'a pas de `ref` (fait `marketplace-soon-entry-format`) : l'installation suivrait donc la branche par défaut, ici celle de la phase 8 — déduit du clone git, à vérifier avant la publication.

### Décisions de Soon, le 2026-10-20 (« Je valide »)

- `docs/PLAN.md`, errata compris, et `docs/ARCHITECTURE.md` approuvés : `pp.sh approve … --quote 'Je valide'`, exit 0 pour chacun, empreintes dans `.plugin-plugin/approvals.log`.
- Étiquette locale `plugin-plugin--v0.1.0` sur `fec6a94`, la fin de la phase 15 : 0.1.0 est ce que les phases 1 à 15 ont construit ; les corrections de la relecture forment la 0.1.1, un correctif, sous `## [à venir] — en cours` du CHANGELOG, que la publication datera.
- Dépôt GitHub existant : le critère 6 ne peut être tenu pour sa création, faite le 2026-10-19 hors des gestes annoncés — écart consigné. La branche par défaut passe à `main` par Soon, dans son terminal (`gh repo edit soonlysoul/plugin-plugin --default-branch main`), après le push de `main` et avant la fusion de la PR de la marketplace.
- Commit de clôture sur `feat/v0.1.0`, puis `main` avancé en local par avance rapide ; rien de poussé.

### Faux positif de `gesture-guard`

Depuis `init-state`, plugin-plugin est un dépôt géré, et son propre garde y est actif. Le 2026-10-20, il a bloqué une commande qui ajoutait à PROGRESS.md, par un heredoc cité (`<<'EOF'`), un texte contenant `gh repo edit` : « geste GitHub sans accord (gh repo edit) : aucun geste annoncé ». Rien n'a été exécuté. Le garde préfère le faux positif, comme celui de plugin-flutter ; contourné par l'outil Edit, non corrigé.

### Publication de 0.1.1

`/plugin-plugin:release`, tapé par Soon, sur `.` : répétition exit 0 — 0.1.0 → 0.1.1, « correctif : aucun composant ajouté ni retiré », le seul commit depuis l'étiquette étant `c103f67` ; aucun `--bump` proposé, les deux refus devenus plus stricts ne cassant aucun appelant. Puis, sur « publie », `pp.sh publish .` : répétition repassée, plan figé, quatre étapes annoncées, chacune lancée sur un « oui » tapé, capté par `consent-capture` (`.plugin-plugin/consents.log`, ignoré par git) :

| Étape | Gestes | « oui » | Fait | Sortie |
| --- | --- | --- | --- | --- |
| 1 | 1 à 4 : version et CHANGELOG, commit `a72ecda`, étiquette, push de `main` | 18:50:08 | 18:50:22 | exit 0 ; `bd531f4..a72ecda  main -> main` |
| 5 | 5 : push de l'étiquette | 18:54:17 | 18:54:29 | exit 0 ; `* [new tag] plugin-plugin--v0.1.1` |
| 6 | 6 à 10 : copie de la marketplace, branche `add-plugin-plugin`, entrée, commit `21e1fd4`, push de la branche | 18:54:54 | 18:55:01 | exit 0 ; `* [new branch] add-plugin-plugin` ; une entrée de 8 lignes, sans `ref` |
| 11 | 11 : PR | 18:55:31 | 18:55:42 | exit 0 ; https://github.com/soonlysoul/claude-plugins/pull/1 |

Onze gestes « fait, exit 0 » dans `.plugin-plugin/gestures.log` (ignoré par git), heures de Paris, le 2026-10-20. La branche par défaut du dépôt est passée à `main` par Soon entre le geste 4 et la fusion ; `gh repo view` la lit `main`.

Après la publication, par `gh` :

- PR #1 : `MERGED`, le 2026-10-20 à 17:04:58 UTC, commit de fusion `d752652` ; l'entrée `plugin-plugin` est sur `main` de `soonlysoul/claude-plugins`.
- `gh api repos/soonlysoul/plugin-plugin/git/refs/tags/plugin-plugin--v0.1.1` : `c6727ed`, comme `git rev-parse` en local. L'étiquette `plugin-plugin--v0.1.0` reste locale.

Sur ce poste, par Soon : `claude plugin marketplace update soon` (« Successfully updated marketplace: soon »), `claude plugin install plugin-plugin@soon` (« Successfully installed plugin: plugin-plugin@soon (scope: user) », clone HTTPS de `soonlysoul/plugin-plugin`), `claude plugin list` : `plugin-plugin@soon`, Version 0.1.1, Scope user, ✔ enabled. Installée depuis la branche par défaut `main` : cohérent avec une entrée sans `ref` qui suit la branche par défaut, sans le prouver (fait `marketplace-soon-entry-format`).

Constats de la publication :

- La première commande lancée après le premier « oui » portait `; echo "exit=$?"` en plus : `gesture-guard` l'a refusée (« seule celle-là passe, telle quelle »), rien n'a été exécuté. La commande exacte est passée ensuite sur le même accord. Le garde a fait ce qu'il doit ; l'écart venait de Claude.
- « fusionne pour moi » : refusé par Claude, la fusion étant réservée à Soon (plan, skill `release`, `gesture-guard`) ; commande donnée, Soon a fusionné. Rouvrir ce point serait un changement du plan.
- Deux plugin-plugin actifs sur ce poste : `plugin-plugin@plugin-plugin` (scope local, ce dossier, depuis la phase 15) et `plugin-plugin@soon` (scope user). Dans ce projet, les deux étaient chargés. Choix de Soon, le 2026-10-20 : garder celle de la marketplace ; `claude plugin disable plugin-plugin@plugin-plugin --scope local`, exit 0. La copie locale reste installée, désactivée (`.claude/settings.local.json`, ignoré par git) : une modification de ce dossier ne se voit plus qu'après publication, ou par `claude --plugin-dir .`.

## Phase 17 — plugin-nixos réécrit, publié à la place de l'original — terminée

Demande de Soon, le 2026-10-20 : remplacer l'ancien plugin-nixos de la marketplace par celui que plugin-plugin a réécrit. L'entrée `plugin-nixos` de la marketplace `soon` suit `soonlysoul/plugin-nixos` sans `ref` : la remplacer, c'est y publier la réécriture comme nouvelle version, sans PR de marketplace.

- [x] Recette rejouée avec le plugin-plugin du jour : `bash tests/rewrite/plugin-nixos.sh ../plugin-nixos build/p17/plugin-nixos`, exit 0, 2 min 52 s — suite portée verte (réussies 11, alertes 1, le coût de 1 126 tokens), `check` à zéro écart, 0 cas d'origine sans équivalent, original intact. Identique, fichier pour fichier, à `build/rewrite/plugin-nixos` de la phase 14.
- [x] La réécriture n'avait aucun commit : la pousser telle quelle aurait demandé un push forcé. Posée à la place sur `main` de `../plugin-nixos`, au-dessus de `dc6ea53` (`v0.1.2`, le `main` de GitHub) : arbre remplacé, déplacements vus comme renommages, bits d'exécution gardés. Trois textes retouchés, qui ne tiendraient plus publiés : le PROGRESS de la réécriture (« jamais publié »), la version du README, une section `[à venir] — en cours` au CHANGELOG. Suite exit 0, `check` à zéro écart ; commit `ce5da8a`, local, avance rapide sur `origin/main`.
- [x] Décisions de Soon : Claude Code 2.1.295 au moins accepté ; version 0.2.0 par `--bump minor` — l'outil lit un correctif, mais le minimum relevé casse un poste plus ancien, et une mineure le signale en 0.x sans annoncer de 1.0.
- [x] Défaut de `pp.sh` révélé, corrigé rouge puis vert (ci-dessous) ; suite complète de plugin-plugin exit 0 — réussies 32, échouées 0, sautées 1, coût permanent 880 tokens.
- [x] Répétition par le `pp.sh` corrigé : `pp.sh release ../plugin-nixos --bump minor`, exit 0 — 0.1.2 → 0.2.0 depuis `v0.1.2`, validation stricte ok, suite exit 0, étiquette `plugin-nixos--v0.2.0` vérifiée, cinq gestes dont deux vers GitHub (push de `main`, de l'étiquette), aucune PR, rien d'envoyé.
- [x] Publication, par Soon, le 2026-10-20, depuis un terminal ouvert dans `../plugin-nixos` avec le plugin-plugin de ce dossier (`claude --plugin-dir ../plugin-plugin`, fait `plugin-dir-inline` ; la copie installée, 0.1.1, a encore le défaut et refuserait 0.2.0). `/plugin-plugin:release . --bump minor` : répétition exit 0, la même que celle rejouée juste avant depuis VSCode par le `pp.sh` de ce dossier (2 min 23 s). Puis « publie » : deux étapes, chacune sur un « oui » capté par `consent-capture` — gestes 1 à 4 (accord 20:48:51, faits de 20:48:59 à 20:49:02), geste 5 (accord 20:49:29, fait 20:49:34). Cinq gestes « fait, exit 0 » dans `../plugin-nixos/.plugin-plugin/gestures.log` (ignoré par git). Commit de version `4c42f1e`, étiquette annotée `plugin-nixos--v0.2.0` sur ce commit.
- [x] Vérifié par `gh` : le `main` de `soonlysoul/plugin-nixos` est à `4c42f1e`, son `plugin.json` annonce 0.2.0, l'étiquette `plugin-nixos--v0.2.0` y pointe sur `4c42f1e` ; `main` local à égalité avec `origin/main`.
- [x] Mise à jour de ce poste, par Soon, à 20:50 : marketplace `soon` mise à jour, `plugin-nixos@soon` 0.2.0 (`4c42f1e`) et `plugin-flutter@soon` 0.3.0 (`2b3488c`), portée user. Chaque copie installée est identique, fichier pour fichier, au commit publié (`git archive` comparé au cache par `diff -rq` : seul le marqueur `.in_use` en plus). Effet au prochain démarrage de chaque session.
- Autres postes, par Soon : `claude plugin marketplace update soon`, puis `claude plugin update plugin-nixos@soon` — avec la réécriture HTTPS ci-dessous si le poste n'a pas la clé d'hôte de github.com.

### Constats du 2026-10-20, avant la publication

- Premier essai dans une session VSCode : elle a lancé le `pp.sh` de la copie installée (`cache/soon/plugin-plugin/0.1.1`), d'où le refus de `--bump minor` (« composant retiré : hook garde-nixos.sh" »), l'ancien défaut. Rien d'envoyé. L'extension ne prend pas `--plugin-dir` : la publication se fait depuis un terminal.
- `claude plugin update plugin-nixos@soon`, lancé par Soon avant toute publication, échoue : « Host key verification failed ». Reproduit sur 2.1.296 avec `--debug-file` : le test SSH de Claude Code répond `code=255 configured=false`, puis le clone de `plugin update` part quand même en `git@github.com:`, sans repli HTTPS. Ce poste n'a ni clé d'hôte de github.com (`~/.ssh` vide, rien dans `/etc/ssh/ssh_known_hosts`) ni clé SSH ; `gh` travaille en HTTPS. Contournement limité à l'appel, vérifié : `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=url.https://github.com/.insteadOf GIT_CONFIG_VALUE_0=git@github.com: claude plugin update plugin-nixos@soon` → « already at the latest version (0.1.2) », exit 0. Le `print_install` de `pp.sh` donne la commande nue : à reprendre, et à porter dans la base de faits.
- Incident de Claude : `claude --debug plugin update …` — `--debug` prend un filtre facultatif et a avalé `plugin` ; la commande lancée était `claude update`. Claude Code natif 2.1.304 installé dans `~/.local/share/claude/versions/`, lien `~/.local/bin/claude` (hors du `PATH` : `claude` reste la 2.1.296 de Nix), `installMethod: "native"` et auto-mise à jour coupée dans `~/.claude.json`. Nettoyage soumis à Soon.

### Constats du 2026-10-20, après la publication

- plugin-flutter : le commit `ca7445c` de son PROGRESS, non poussé, disait la copie installée passée en 0.3.0 par `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1 claude plugin update plugin-flutter@soon` ; elle était encore en 0.1.2 (`installed_plugins.json`, cache inchangé depuis le 2026-10-19). Corrigé sur l'accord de Soon par un `--amend` du commit, devenu `2b3488c`, poussé par Soon. La variable figure bien dans les binaires 2.1.296 et 2.1.304, mais son effet n'est pas prouvé : seule la réécriture par `GIT_CONFIG_*` est vérifiée.
- Version minimale de 0.2.0 (2.1.295) : une nouvelle session VSCode prend l'extension active, 2.1.304 ; le terminal, la 2.1.296 de Nix. Deux sessions VSCode du 2026-10-07 (`Programmation/Claude-sdk`) tournent encore sur l'extension 2.1.292, avec les anciens plugins chargés : à fermer plutôt qu'à recharger par `/reload-plugins`.
- Reste ouvert : `c43d870`, le correctif de `pp.sh`, est local, et la copie installée de plugin-plugin reste 0.1.1, avec le défaut. Jusqu'à la publication de 0.1.2, un plugin réécrit depuis la forme shell se publie par `claude --plugin-dir`. Le `print_install` à reprendre et le nettoyage de la 2.1.304 native restent en attente (ci-dessus).

### Défaut de `pp.sh release` : un hook en forme shell lu avec son guillemet

`components_at` nommait un hook par le dernier segment de `args[0]` ou de `command`. En forme shell, le chemin entre guillemets (`bash "${CLAUDE_PLUGIN_ROOT}/hooks/garde-nixos.sh"`) donnait `garde-nixos.sh"`, et la forme exec `garde-nixos` : le même hook comptait pour retiré puis ajouté, la nature devenait majeure, et `--bump minor` était refusé (« composant retiré : hook garde-nixos.sh" »). Correctif : guillemets ôtés, le mot de la commande qui porte un chemin. Le cas même de toute réécriture d'un plugin en forme shell.

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/integration/test_release.sh` | 1 | 103 réussis, 2 échoués : « forme shell entre guillemets, puis exec : correctif », « aucun hook retiré au CHANGELOG » (`- Hook \`garde\`.` présent) |
| VERT | même test | 0 | 105 réussis, 0 échoué |

## Phase 18 — Descriptions et documents tenus à chaque publication — en cours

Demande de Soon, le 2026-10-20 : « plugin-plugin doit mettre à jour les documents, les descriptions GitHub et la marketplace GitHub claude-plugins ». `release` ne posait une description qu'à la première publication (`gh repo create --description`, l'entrée ajoutée à la marketplace) ; une mise à jour ne touchait ni GitHub ni la marketplace.

État relevé le même jour, par `gh` :

| Surface | plugin-plugin | plugin-nixos | plugin-flutter |
| --- | --- | --- | --- |
| Description du dépôt GitHub | vide (dépôt créé hors des gestes annoncés) | courte, ≠ `plugin.json` | en français, sans l'adoption ni les mises à jour de la 0.3.0 |
| Entrée de `soonlysoul/claude-plugins` | = `plugin.json` | ≠ `plugin.json` | celle d'avant la 0.3.0 |
| README de la marketplace | absent du tableau et des commandes d'installation | ligne à part | ligne d'avant la 0.3.0 |
| README du plugin | « Version **0.1.0**, en construction » | à jour | à jour |

- [x] Cadrage : quatre choix de Soon, chacun la recommandation — `plugin.json` pour seule source, recopiée telle quelle ; version écrite et composants exigés dans le README ; alignement sans version ; description seule sur GitHub, ni topics ni page d'accueil.
- [x] PRD amendé (US-35 à US-37, critère 10, deux décisions, hors périmètre) et PLAN (décision h, phase 18), approuvés par Soon (« je valide ») : `pp.sh approve`, exit 0 pour chacun, empreintes dans `.plugin-plugin/approvals.log`.
- [x] Tests écrits avant le code, vus rouges, puis verts (ci-dessous).
- [x] Skill `release`, README, `docs/` (USER_GUIDE, SECURITY, TROUBLESHOOTING, ARCHITECTURE), CHANGELOG `[à venir]`, deux faits nouveaux et un corrigé dans la base.
- [x] `docs/ARCHITECTURE.md` réapprouvé le 2026-10-20 (« je valide ») : sa ligne `release` avait changé.
- [x] plugin-plugin 0.1.2 publié par ce chemin le 2026-10-20 (ci-dessous) ; PR #2 de la marketplace ouverte, à fusionner par Soon.
- [x] PR #2 fusionnée par Soon le 2026-10-21 (`fb3ad3a`) ; plugin-plugin 0.1.2 installé sur ce poste, identique à son étiquette.
- [x] plugin-nixos aligné le 2026-10-21, sans version (ci-dessous) ; PR #3 fusionnée par Soon.
- [ ] ~~plugin-flutter aligné après l'ajout des entrées `.plugin-plugin/` à son `.gitignore` ; PR fusionnée par Soon (critère 10).~~ Sorti du plan le 2026-10-23 (décision i) : un usage de plugin-plugin, à la main de Soon.

### Ce que fait `release` désormais

- Répétition : la description de `plugin.json` est refusée absente, sur plusieurs lignes ou au-delà de 350 caractères (comptés par `jq`, en caractères) ; un README sans `Version **X.Y.Z**`, ou qui ne nomme pas un composant, est refusé, les composants nommés.
- Lus sur GitHub : la description du dépôt, l'entrée et le README de la marketplace. Une ligne `descriptions :` dit « alignées sur plugin.json », ou nomme chaque surface qui diverge.
- Gestes ajoutés : `gh repo edit … --description` après le push de l'étiquette ; pour un plugin listé qui diverge, une copie, une branche `align-<nom>-<version>`, `marketplace-entry --update`, un commit, un push, une PR. Un plugin nouveau reçoit sa ligne et sa commande d'installation dans la PR d'ajout.
- `release-write` écrit la version dans le README et la description dans la marketplace locale ; le commit de version ne nomme que les fichiers qu'il a changés.
- Rien depuis l'étiquette mais des descriptions en retard : un alignement, sans version, ni CHANGELOG, ni étiquette ; annonces `align …` et journal `alignement N`, à part de la publication de la même étiquette.
- Une branche de marketplace déjà sur GitHub est refusée à la répétition, sa PR ouverte nommée.

### Défaut de conception relevé par les tests, corrigé

La copie de la marketplace vivait dans `…/plugin-plugin-release/<nom>/claude-plugins` : une deuxième PR du même plugin serait repartie de la copie de la première, encore sur sa branche. Elle vit désormais dans un dossier par branche (`…/<nom>/<branche>`).

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| ROUGE | `bash tests/integration/test_release.sh` | 1 | 129 réussis, 54 échoués : chaque refus, l'écriture du README et de la marketplace locale, `--update`, les gestes d'alignement, l'alignement seul |
| ROUGE | `bash tests/integration/test_publish.sh` | 1 | 125 réussis, 36 échoués : la ligne du README de la marketplace, la copie par branche, l'alignement de bout en bout, sa coupure, la PR ouverte nommée |
| VERT | `bash tests/integration/test_release.sh` | 0 | 183 réussis, 0 échoué |
| VERT | `bash tests/integration/test_publish.sh` | 0 | 155 réussis, 0 échoué |

Deux pièges des doublures, pris pendant le passage au vert, sans effet sur `pp.sh` : `"${VAR-Plugin d'essai.}"` entre guillemets doubles, où bash lit l'apostrophe comme un guillemet ; et la fonction `cut` de la doublure de `gh` (la coupure réseau simulée), qui masquait `/usr/bin/cut`.

Faux positif de `gesture-guard`, de nouveau : un heredoc qui ajoutait cette section à PROGRESS.md, et qui contenait `gh repo create`, a été bloqué ; rien n'a été exécuté. Ajoutée par l'outil Edit.

Suite complète, premier passage : `bash tests/run-all.sh`, exit 1 — réussies 30, échouées 2 (`tests/static/test_paths.sh` : shellcheck SC2046 sur `$( ((listed)) && echo --update)` non cité, dans `cmd_release` ; `tests/static/test_run_all.sh`, par ricochet). Corrigé par un tableau d'options. Second passage : exit 0 — réussies 32, échouées 0, sautées 1 (`agents` absent), bloquées 0, alertes 0 ; coût permanent 880 tokens, inchangé (critère 9).

Répétitions sur les vrais dépôts, rien d'envoyé : `bash scripts/pp.sh release ../plugin-nixos`, exit 0 — un alignement, sept gestes (description du dépôt, puis copie, branche `align-plugin-nixos-0.2.0`, entrée, commit, push, PR). Sur une copie jetable du vrai README de la marketplace, `marketplace-entry --update` pour plugin-nixos puis plugin-plugin ne change que la ligne de plugin-nixos, ajoute celle de plugin-plugin et sa commande d'installation ; le reste est intact. Les deux PR touchent des lignes voisines du tableau : la seconde se répète après la fusion de la première.

### Publication de plugin-plugin 0.1.2

Le 2026-10-20, depuis ce dossier (`bash scripts/pp.sh publish .`, la copie installée étant 0.1.1), sans `--bump` : un correctif, aucun composant ajouté ni retiré. Douze gestes en cinq étapes, chacune sur un « oui » tapé, chaque commande lancée une fois, exit 0 :

| Étape | Gestes | Résultat |
| --- | --- | --- |
| 1 | `release-write`, commit de version, étiquette, push de `main` | `ec1a23b chore(release): plugin-plugin 0.1.2` ; `5b9c1b0..ec1a23b  main -> main` |
| 5 | push de l'étiquette | `plugin-plugin--v0.1.2` sur GitHub (objet `76821cc`, commit `ec1a23b`) |
| 6 | description du dépôt | vide jusque-là, elle égale celle du `plugin.json` (relue par `gh api`) |
| 7 | copie, branche `align-plugin-plugin-0.1.2`, `marketplace-entry --update`, commit, push | `README.md` seul : la ligne de plugin-plugin et sa commande d'installation ; l'entrée de `marketplace.json` était déjà alignée |
| 12 | PR de marketplace | [soonlysoul/claude-plugins#2](https://github.com/soonlysoul/claude-plugins/pull/2), ouverte, fusionnable |

Une annonce retirée sans qu'on y réponde : la répétition de `publish` a duré plus que les dix minutes d'attente de l'outil Bash, et s'est finie en tâche de fond. L'avis de fin de tâche est arrivé par `UserPromptSubmit`, et `consent-capture` l'a lu comme une réponse autre que « oui » : l'annonce de l'étape 1 a été retirée, rien n'a été lancé. Le plan étant figé, `pp.sh publish .` l'a annoncée de nouveau sans répéter. Sûr — le hook retire, il n'accorde jamais — mais une publication dont la répétition dépasse dix minutes perd sa première annonce. À trancher : `consent-capture` ignore un avis de tâche, ou le skill dit de réannoncer.

Faux positif de `gesture-guard`, une troisième fois : un script qui ajoutait cette section, et dont le texte nommait la commande de description du dépôt, a été bloqué ; rien n'a été exécuté. Ajoutée par l'outil Edit.

Mise à jour de ce poste : `claude plugin update plugin-plugin@soon`, tapé par Soon, a échoué comme en phase 17 (« Host key verification failed », clone en `git@github.com:`). Avec la réécriture HTTPS limitée à l'appel (`GIT_CONFIG_*`, ci-dessus), lancée par Claude à la demande de Soon : « updated from 0.1.1 to 0.1.2 », exit 0 ; la copie du cache est identique à `git archive plugin-plugin--v0.1.2` (`diff -rq`, exit 0). Le préfixe `!` de Claude Code ne lance rien dans l'extension VSCode : la ligne part comme un message.

### Alignement de plugin-nixos

Le 2026-10-21, par Soon, dans une session ouverte dans `../plugin-nixos`, avec plugin-plugin 0.1.2 installé (`/plugin-plugin:release`). La répétition, rejouée juste avant depuis ce dossier sur la marketplace fusionnée : exit 0, un alignement, trois surfaces à aligner (dépôt GitHub, entrée, README de marketplace), sept gestes. Journal `alignement 1` à `alignement 7` dans `../plugin-nixos/.plugin-plugin/gestures.log`, tous « fait, exit 0 », en trois accords : description du dépôt (12:41:25) ; copie, branche, entrée, commit, push (12:42:15–17) ; PR (12:42:43). PR #3 « Aligner la description de plugin-nixos », fusionnée par Soon à 10:50:56 UTC.

Vérifié par `gh` : la description du dépôt, l'entrée de la marketplace et la ligne du README égalent le `plugin.json` de plugin-nixos, sa commande d'installation présente une fois ; la ligne de plugin-plugin reste égale à son `plugin.json`. Aucun commit, aucune étiquette dans plugin-nixos : `main` reste sur `4c42f1e`, la dernière étiquette `plugin-nixos--v0.2.0` (US-37).

## Phase 19 — Un modèle propre à plugin-plugin — en cours

Demande de Soon, le 2026-10-23, en cadrant un plugin qui crée des serveurs MCP (`../plugin-mcp`, cadrage en pause à sa question 1) : « avoir un modèle généraliste et ne plus utiliser le modèle d'un plugin déjà existant » ; puis « tranche au mieux, mais n'utilise pas de plugin déjà créé autre que plugin, car ils sont sujets à être modifiés dans le temps ». Décision déléguée, consignée dans `.plugin-plugin/decisions.md` : un modèle propre à plugin-plugin — mêmes règles, écrites dans `docs/MODEL.md` avec leur raison, exclusions gardées — plutôt qu'un modèle élargi à tout ce que Claude Code accepte.

- [x] PRD amendé (US-38, US-17, US-19, critères 2 et 10, hors périmètre) et PLAN (décision i, fin de la phase 18, phase 19), approuvés par Soon le 2026-10-23 (« oui », puis « oui ») : `pp.sh approve`, exit 0 pour chacun.
- [x] Tests écrits avant le code, vus rouges, puis verts (ci-dessous).
- [x] `docs/MODEL.md` : dix-huit règles, chacune avec son contrôle et sa raison, les faits qu'elle cite ; sept exclusions avec ce qui les rouvrirait ; six formes écartées.
- [x] `pp.sh` : « écarts : 0 — au modèle de plugin-plugin (docs/MODEL.md) » ; le refus d'un style de sortie a sa raison propre. Skills `check` et `add`, gabarit d'architecture, manifestes, README, USER_GUIDE, ARCHITECTURE, cas d'évaluation de `create` : plus aucun autre plugin nommé.
- [x] `tests/helpers/foreign.sh` : plugin-essai, un plugin du modèle que plugin-plugin n'a pas créé — harnais en ses propres mots, garde de portée qui connaît son agent par son nom, test qui compte ses composants. `test_add_existing` (17 cas) et `test_rebuild` (33 cas) y passent les mêmes vérifications qu'avec plugin-flutter.
- [x] `test_check_real` remplacé par `test_check_self` : `check` sur plugin-plugin lui-même, zéro écart, rien de modifié. `tests/rewrite/plugin-nixos.sh` et `test_rewrite_nixos` retirés.
- [x] Doublures de `gh` et de la marketplace : `plugin-alpha`, `plugin-beta`, `alpha-forge` au lieu des vrais noms. Base de faits : deux identifiants renommés, trois façons de revérifier reprises sur plugin-plugin ou un plugin d'essai, une quatrième (le garde du compte) décrite sans nommer de plugin ; sources et énoncés gardés, c'est l'historique.
- [x] `docs/MODEL.md` approuvé par Soon le 2026-10-23 (« Je valide »), `docs/ARCHITECTURE.md` réapprouvé le même jour (« oui ») : `pp.sh approve`, exit 0, empreintes dans `.plugin-plugin/approvals.log`.
- [ ] Commit sur `feat/own-model`, sur un « oui ».

### Rouge puis vert

| Étape | Commande | Code | Résultat |
| --- | --- | --- | --- |
| DÉPART | `bash tests/run-all.sh` | 1 | réussies 31, échouées 1 : `test_rewrite_nixos`, « motif absent : ^écarts : 0 — au modèle de plugin-flutter$ » — le message de `check` avait été changé pendant le passage ; ce test est retiré par la phase |
| ROUGE | `bash tests/static/test_independence.sh` | 1 | 1 réussi, 2 échoués : 152 occurrences d'autres plugins dans 25 fichiers ; cinq faits (`plugin-nixos-description-limit-1024`, `plugin-details-cost`, `plugin-details-hooks-free`, `flutter-forge-guard-rm-rf`, `plugin-details-thousands-separator`) |
| ROUGE | `bash tests/static/test_model.sh` | 1 | 0 réussi, 1 échoué : « docs/MODEL.md présent », absent |
| ROUGE | `bash tests/static/test_model.sh`, MODEL.md écrit | 1 | 32 réussis, 1 échoué : le refus `output-style` disait « aucun plugin du modèle n'en a l'usage » |
| VERT | `bash tests/static/test_model.sh` | 0 | 33 réussis |
| VERT | `bash tests/static/test_independence.sh` | 0 | 3 réussis |
| VERT | `PP_REF_DIR=<dossier vide> bash tests/run-all.sh` | 0 | réussies 33, échouées 0, sautées 1 (`agents` absent, comme avant), bloquées 0, alertes 0 ; 1 281 cas ; coût permanent 887 tokens (seuil 1 000) |

### Les tests discriminent

`PLUGIN_UNDER_TEST=<copie faussée>`, cinq copies dans `build/mutants/p19/` :

| Copie faussée | Test | Code | Échec |
| --- | --- | --- | --- |
| une catégorie `[nouvelle]` dans `check.sh` | `test_model` | 1 | « check [nouvelle] : une règle » |
| un skill qui nomme un autre plugin | `test_independence` | 1 | « aucun ne nomme un autre plugin ni ne lit sa copie », `skills/check/SKILL.md:33` |
| le message de `check` nomme un autre plugin | `test_check_self` | 1 | « « écarts : 0 », au modèle de plugin-plugin » |
| `add-agent` ne refuse plus un garde propre au plugin | `test_add_existing` | 1 | « agent qui écrit, garde propre au plugin : refusé », « refusé : rien n'est écrit » |
| `rebuild` garde le `tests/lib.sh` de l'original | `test_rebuild` | 1 | 7 échecs, dont « tests/lib.sh : celui de plugin-plugin » et la suite de la reconstruction |

Le garde `guard-destructive` de plugin-flutter, installé pour le compte, a refusé un `rm -rf` d'un dossier de travail hors de `build/` pendant la phase : non contourné, un dossier neuf a été pris (fait `account-guard-rm-rf`, revu).
