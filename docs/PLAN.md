# Plan : plugin-plugin v0.1

> PRD source : `docs/PRD.md` · Modèle : plugin-flutter seul
> (`soonlysoul/plugin-flutter`, v0.1.2) · Design : sans objet, aucune interface.
> Mesures de référence : Claude Code 2.1.296, 2026-10-19.

**Statut : APPROUVÉ** le 2026-10-20 (« je valide »).

Approuvé le 2026-10-19, par Soon (« oui juste change le nom par plugin-plugin »), renommage
compris. Toute modification d'un document approuvé le repasse en revue.

Amendé le 2026-10-20, avec le PRD (US-35 à US-37, critère 10) : décision h et phase 18.

Errata de la clôture (phase 16, 2026-10-20), corrigés en une fois dans le texte :

1. « Tests et validation » : la validation stricte de la racine couvre aussi `plugin.json` ;
   mesuré en phase 2 (fait `validate-root-covers-plugin`). La suite vise toujours chaque cible.
2. « Évaluations », bac à sable : `~/Documents/Nixos` n'existe pas sur ce poste ; `~/Nixos`
   ne mentionne pas bwrap, absent du `PATH`.
3. Phase 14 : aucun sous-module ne cite plugin-nixos sur ce poste ; seul le clone a pu être prouvé
   intact (Soon, le 2026-10-20).

## Décisions architecturales

Valables pour toutes les phases. Une phase s'y réfère ; aucune ne les rouvre.

### Principes, repris de plugin-flutter

- **Petit d'abord.** Une v0.1 éprouvée vaut mieux qu'une v0.1 large.
- **La session principale orchestre** ; un agent exécute une tâche bornée et rend un rapport.
- **Déterministe = script ou hook, jugement = skill.** Ce qui doit toujours se produire n'est
  pas une consigne.
- **Rien n'est approuvé implicitement** : documents, gestes GitHub et lancements payants exigent
  une trace d'accord.
- **Honnêteté des résultats** : chaque étape est réussie, échouée, bloquée ou non exécutée, avec
  la commande lancée et son code de sortie.
- **État sur disque** : le travail reprend depuis git et un point de reprise, jamais depuis le
  souvenir d'une session.

### Le modèle de plugin

- **Le modèle est plugin-flutter.** Un plugin du modèle :
  - s'appelle `plugin-<domaine>`, vit dans le dépôt dédié `soonlysoul/<nom>`, plugin à la racine ;
  - a un `.claude-plugin/plugin.json` portant `name`, `version` SemVer, `description`,
    `author.name` « Soon » **sans e-mail**, `license` MIT, `homepage` = `repository` = son dépôt
    GitHub, et aucun champ inconnu ;
  - a une marketplace locale `.claude-plugin/marketplace.json` : une entrée `"source": "./"`,
    même nom que le manifeste, sans `version` ;
  - a une LICENSE MIT, un README, un CHANGELOG en français (Keep a Changelog), un
    ARCHITECTURE.md, un PROGRESS.md, et `docs/` (INSTALLATION, USER_GUIDE, SECURITY,
    TROUBLESHOOTING) ; aucun CLAUDE.md à la racine ;
  - range ses composants à la racine : `skills/`, `agents/`, `hooks/hooks.json` et
    `hooks/scripts/`, `templates/` ; ses tests dans `tests/` (statiques, hooks, scénarios).
- **Une seule extension du modèle** (décision a) : `scripts/` à la racine pour un outil appelé
  par plusieurs skills, cité par `${CLAUDE_PLUGIN_ROOT}` et soumis aux mêmes tests de chemins que
  `hooks/scripts/`. plugin-flutter n'en a pas besoin ; plugin-plugin et plugin-nixos si.
- **Langues** : code, identifiants et fichiers du plugin en anglais par défaut (choix au cadrage,
  plugin par plugin) ; messages et documents en français.
- **Hooks** :
  - forme exec (`"command": "bash"`, le script dans `args`) — Claude Code 2.1.295 minimum ;
  - fail-closed : exit 2 sur toute erreur interne et `"onFailure": "block"` ; fail-open : exit 0
    et `"onFailure": "continue"` ;
  - `timeout` toujours déclaré, `#!/usr/bin/env bash`, variables entre guillemets, raison sur
    stderr, aucun chemin absolu ;
  - inertes hors de leur contexte, car un plugin installé pour le compte s'applique à toutes les
    sessions ;
  - indépendants les uns des autres : les hooks d'un même événement tournent en parallèle, dans
    un ordre quelconque.
- **Agents** :
  - en-tête strict, une ligne par clé : `name`, `description`, `tools`, `model`, `color` ;
  - `tools` toujours déclaré, jamais `Agent` ; omis, l'agent hériterait de tous les outils ;
  - description « Use this agent when … ; not for … », corps en responsabilités, démarche et
    format de sortie, rapport STATUS / FILES_CHANGED / COMMANDS_RUN / OPEN_QUESTIONS ;
  - limites d'écriture et liste blanche Bash imposées par un garde de portée, comme
    agent-scope-guard.
- **Skills** :
  - en-tête `name`, `description`, `argument-hint`, `when_to_use` ; jamais `allowed-tools`
    (il accorde sans demander et ne restreint rien) ;
  - description « <ce que fait le skill>. Use when … ; not for … », complétée de quelques phrases
    de déclenchement citées en français ; description et `when_to_use` réunis sous 1 536
    caractères ; SKILL.md sous 500 lignes, à l'impératif, détails dans `reference/` ;
  - questions de validation posées en texte, puis arrêt ; point de reprise écrit à chaque étape ;
    deux échecs identiques d'une commande arrêtent le skill et exposent le blocage.

### plugin-plugin lui-même

- **Nom** : `plugin-plugin`, d'abord nommé plugin-agent, renommé le 2026-10-19 avant toute
  publication — donc sans coût. Vérifié libre ce jour-là : `soonlysoul/plugin-plugin` absent de
  GitHub, absent de la marketplace `soon`.
- **Sept skills**, invoqués par `/plugin-plugin:<skill>` : `frame` (cadrage), `create`,
  `resume`, `add`, `check` (conformité), `release`, `reaudit`. Aucun agent en v0.1.
- `release` et `reaudit` ne se lancent que sur demande explicite (`disable-model-invocation`),
  pour tenir le budget.
- **Budget** : moins de 1 000 tokens permanents, mesuré par `claude plugin details` dans la suite
  de tests (critère 9). plugin-flutter, pour comparaison : environ 830.
- **La logique déterministe vit dans un seul outil en ligne de commande**, appelé par les skills,
  testé sans session.
- **État de travail** dans le dépôt du plugin cible, sous `.plugin-plugin/` : point de reprise,
  journal des accords, journal des gestes de publication. Jamais dans la racine du plugin installé
  (elle change à chaque mise à jour), jamais dans `~/.claude`. Sa présence dans git se tranche en
  phase 5.
- **Base de faits versionnée** dans plugin-plugin : chaque fait porte son énoncé, la version de
  Claude Code, la date, la source, la façon de le revérifier et son statut (confirmé, infirmé, à
  vérifier).

### Tests et validation

- **Suite déterministe** : bash et jq, sans réseau, sans session, sans quota. `tests/run-all.sh`
  sort en 0 (tout passe), 1 (un échec), 2 (un prérequis manque).
- **`claude plugin validate --strict` sur chaque cible.** La validation de la racine couvre la
  marketplace et `plugin.json` ; la suite vise malgré tout `.claude-plugin/plugin.json` et chaque
  dossier de composants présent (`skills`, `agents`), pour nommer la cible en défaut. Le validateur ne voit ni un en-tête d'agent cassé ni un script de
  hook absent : des tests statiques stricts les couvrent.
- **Doublures** : `gh`, les dépôts distants et `claude` sont remplacés dans le PATH ; les gestes
  GitHub se testent contre des dépôts nus locaux.
- **Chaque test prouve qu'il discrimine** : il échoue sur une copie faussée du plugin.
- **Rouge puis vert** : la sortie du test en échec, puis celle du même test qui passe, sont
  consignées dans PROGRESS.md, avec la commande et le code de sortie.
- **Scénarios headless** (`claude -p --plugin-dir`, hors bac à sable, Bash disponible) : jamais
  lancés par `run-all.sh` ; chacun après accord, avec une estimation.
- Le garde de l'ancien flutter-forge, installé pour le compte, refuse `rm -rf` hors `build/` dans
  toutes les sessions. Il n'est jamais contourné.

### Évaluations

- **Format** : un cas par `evals/<cas>/case.yaml`, `schema_version: "1.0"` obligatoire ;
  correcteurs `regex`, `tool_order`, `tool_used`, `file_exists`, `llm` (champ `criteria`),
  `baseline`. Un bras témoin sans le plugin tourne par défaut.
- **Règles** : au moins un cas qui ne doit pas déclencher par suite ; au moins un correcteur de
  résultat par cas ; trois exécutions par cas au moins ; **un cas que le témoin réussit est
  refusé**. Origine : la première évaluation (recover-session de plugin-flutter) a donné Δ = 0.
- **Les cas viennent des demandes concrètes** recueillies avant d'écrire le skill : celles qui
  doivent le déclencher, celles qui ne le doivent pas.
- **Lancement** : toujours `--no-publish` (sinon le rapport part sur claude.ai) et
  `--max-cost-usd` (3 USD par défaut, modifiable avant chaque lancement) ; `--keep-temp` quand une
  hypothèse doit être vérifiée dans les traces. Jamais `--trust-plugin`, que l'outil présente
  comme l'équivalent de `--dangerously-skip-permissions` ; jamais `--scaffold` sur un cas qu'on
  n'a pas écrit.
- **Avant chaque lancement** s'affichent le nombre de sessions (cas × exécutions × bras), le coût
  estimé (0,13 à 0,23 USD par session, mesuré), le plafond et le compte qui paie. Le rapport
  reste sur le poste, hors git.
- **Bac à sable** : Bash y reste indisponible tant que bwrap n'est pas appliqué sur le poste. Sa
  déclaration et son application, dans la configuration du poste, reviennent à Soon. Un cas qui a besoin de
  Bash est « bloqué », avec la cause, jamais « réussi ».
- **Décision c** : les suites des sept skills de plugin-plugin sont écrites et vérifiées sans être
  lancées, phase après phase ; elles ne tournent qu'après l'application de bwrap et sont
  « bloquées » d'ici là. Le critère 5 se prouve sur le témoin, dont le skill s'évalue sans Bash.
- Un serveur MCP sans doublure dans `evals/mocks/` n'est pas démarré pendant une évaluation.

### GitHub et publication

- **Lecture par `gh api` seulement.** La marketplace se lit sur `soonlysoul/claude-plugins`,
  jamais dans la copie locale, qui retardait de plusieurs heures le 2026-10-19.
- **Gestes** (création de dépôt, push, PR, push d'étiquette) : chacun affiché avec sa commande
  exacte, exécuté sur un « oui » littéral ; toute autre réponse vaut refus. Décision g : un hook
  capte le « oui » tapé, un garde ne laisse passer qu'une fois la commande annoncée ; chaque geste
  est journalisé (fait, échoué, commande qui reprend).
- **La marketplace ne change que par une PR**, fusionnée par Soon. Jamais : supprimer un dépôt,
  forcer un push, réécrire un historique publié, retirer un plugin, fusionner.
- **Versions** : correctif pour une consigne corrigée, mineure pour un composant ajouté, majeure
  pour un changement qui casse l'existant. `version` dans `plugin.json` seulement.
- **Étiquettes** : `{nom}--v{version}`, posées par `claude plugin tag`, qui vérifie la concordance
  de `plugin.json` et de l'entrée de marketplace ; `--dry-run` pour la répétition. Les étiquettes
  `v0.1.x` existantes ne sont pas touchées.
- **Décision b** : 0.1.0 n'est jamais publiée, elle reçoit une étiquette locale à la clôture ;
  0.1.1 est la première publication.
- **Décision h** (2026-10-20) : la description du `plugin.json` est la seule source de la
  description du dépôt GitHub (`gh repo edit --description`), de l'entrée de la marketplace
  `soon`, de la ligne du plugin dans le README de la marketplace, avec sa commande
  d'installation, et de la marketplace locale. La répétition lit les trois premières sur GitHub
  et ajoute un geste par surface qui diverge ; la marketplace change par la même branche et la
  même PR qu'un ajout. Sans rien à publier depuis l'étiquette, seuls ces gestes : un alignement,
  sans version ni étiquette.

### Ré-audit

- **Sonde** : `claude plugin init <nom> --with skills agents hooks mcp lsp output-style channel`,
  lancée avec HOME et CLAUDE_CONFIG_DIR pointés sur un dossier jetable — jamais dans
  `~/.claude/skills`. Sa sortie est conservée par version de Claude Code ; deux versions
  comparées donnent les formats changés.
- **La validation stricte l'emporte** sur un fait qu'elle contredit, et le fait est signalé à
  corriger.
- Le gabarit MCP de la sonde lance `bun install` au démarrage, contraire à « aucune installation
  impérative » : jamais repris tel quel. `--author-email` y prend l'e-mail git par défaut : jamais
  recopié.

### Dossiers et reconstructions

- **Décision d** : reconstructions, réécriture et témoin vivent dans `build/` de plugin-plugin,
  ignoré par git. Les originaux ne sont que lus ; leur intégrité se prouve par leur HEAD et
  `git status --porcelain`, avant et après.
- **Décision e** : reconstruire, c'est générer la charpente et importer le contenu métier tel
  quel, sans exigence d'évaluation. Pour plugin-nixos, tout le métier est importé sauf ce que le
  modèle impose : forme des hooks, arborescence, harnais de tests.
- **Décision f** : le cadrage s'écrit dans `docs/` du dossier cible ; la création accepte un
  dossier qui ne contient que ce cadrage approuvé, refuse tout le reste et n'écrase jamais rien.

### Écarté, et ce qui le rouvrirait

- **Hooks à prompt** : non déterministes, ils coûtent du quota à chaque appel et ne se testent
  pas sans session. Rouvert si un contrôle ne s'exprime pas en script.
- **Scripts utilitaires de plugin-dev** : périmés (`#!/bin/bash`, `matcher` exigé sur `Stop`,
  `tool_result` au lieu de `tool_response`) et sans tests.
- **Réglages `.claude/<plugin>.local.md`** : les options de plugin sont hors périmètre, et Claude
  Code protège l'écriture de ses fichiers de configuration sous `.claude/`.
- **`AskUserQuestion` dans les skills**, **`commands/`**, **`version` dans l'en-tête d'un skill**,
  **agent valideur** : plugin-flutter pose ses questions en texte ; `commands/` est une forme
  ancienne exclue par le PRD ; `version` n'est pas un champ officiel ; la conformité se contrôle
  par script.

---

## Phase 1 : Amorce — plugin-plugin 0.1.0 vide et vert

**User stories** : aucune — amorçage (PRD, « Notes complémentaires ») ; prépare US-6 et US-25.
**Critères de succès** : 9.

### Ce qu'on livre

Un plugin-plugin chargeable par `--plugin-dir`, sans aucun composant, dont la suite déterministe et
la validation stricte passent. Son coût permanent est mesuré dès maintenant, et les hooks du
projet surveillent les scripts shell.

### Critères d'acceptation

- [ ] Manifestes au modèle : `plugin-plugin`, 0.1.0, `author.name` sans e-mail, MIT ; marketplace
      locale `"source": "./"` ; LICENSE, README, CHANGELOG (0.1.0 en cours), `.gitignore`
      (`build/`, résultats d'évaluation).
- [ ] La suite sort en 0 ; les codes 1 (manifeste faussé) et 2 (jq absent) sont vérifiés.
- [ ] `validate --strict` passe sur `.` et sur `.claude-plugin/plugin.json` ; un dossier de
      composants absent est « sauté », jamais réussi en silence.
- [ ] Le coût permanent mesuré par `claude --plugin-dir . plugin details plugin-plugin` est
      affiché ; la suite échoue au-delà de 1 000 tokens ; sans `claude`, l'étape est « bloquée »
      (critère 9).
- [ ] Sondes consignées dans PROGRESS.md : une `homepage` vers un dépôt GitHub encore inexistant
      empêche-t-elle le chargement (cela décide si `homepage` entre dès 0.1.0 ou à la
      publication) ; `plugin details` par `--plugin-dir` sans quota.
- [ ] Le hook Stop du projet signale un `.sh` modifié et propose `bash tests/run-all.sh`.

### Preuve

`bash tests/run-all.sh` — vue en échec avant les manifestes (exit 1, manifeste absent nommé), puis
exit 0 avec « échouées : 0 » ; les deux sorties consignées.

### Bloquée par

Aucune — démarrable immédiatement.

---

## Phase 2 : Base de faits et ré-audit

**User stories** : US-31, US-32, US-33. **Critères de succès** : 8.

### Ce qu'on livre

La base de faits initiale, et le ré-audit qui dit quoi revérifier selon la version de Claude Code
installée. L'instantané de `plugin init` est pris **maintenant**, sur 2.1.296 : après la prochaine
mise à jour, il n'y aurait plus de point de comparaison. Skill `reaudit`, sur demande explicite.

### Critères d'acceptation

- [ ] Import initial : les mesures de la phase A de plugin-flutter et ses constats des phases B à
      F ; les faits du 2026-10-19 (validation par cible, `plugin init`, `plugin eval`,
      `plugin tag`, `plugin details`, garde de flutter-forge, retard de la copie locale) ; les
      faits venus de plugin-dev, marqués « à vérifier », dont ses deux contradictions avec la
      phase A (`when_to_use` « déprécié », rechargement des hooks) ; la limite de longueur des
      descriptions (1 536 chez plugin-flutter, 1 024 chez plugin-nixos).
- [ ] Version inchangée (doublure 2.1.296) : « rien à revérifier depuis la version 2.1.296 », et
      les deux listes, faits et formats, sont vides (US-31, critère 8).
- [ ] Version plus récente (doublure 2.1.297) : tous les faits mesurés sur 2.1.296 sont listés ;
      un fait mesuré sur 2.1.297 ne l'est pas (US-31).
- [ ] Instantané réel de 2.1.296 versionné, produit sans rien écrire dans `~/.claude` (empreinte
      de `~/.claude/skills` identique avant et après) ; deux instantanés d'essai qui diffèrent
      d'un fichier font lister ce format comme changé (US-32, critère 8).
- [ ] Un fait que la validation stricte contredit sur un exemple d'essai est signalé « à
      corriger » ; la validation l'emporte (US-33).
- [ ] Suite d'évaluation de `reaudit` écrite.

### Preuve

`bash tests/run-all.sh` — tests du ré-audit vus en échec puis verts ; puis le ré-audit réel, qui
affiche « rien à revérifier depuis la version 2.1.296 ».

### Bloquée par

Phase 1.

---

## Phase 3 : Cadrage

**User stories** : US-1, US-2, US-3, US-4. **Critères de succès** : prépare le 3.

### Ce qu'on livre

`frame` interroge une question à la fois, chacune avec une recommandation motivée, consigne
chaque décision déléguée, écrit le PRD et l'architecture du futur plugin dans `docs/` du dossier
cible, en brouillon, et les fait approuver explicitement. Un hook repasse en revue tout document
approuvé qui est modifié.

### Critères d'acceptation

- [ ] Chaque question porte une recommandation motivée ; une décision déléguée (« tranche le
      mieux ») est consignée avec le choix, la raison et la mention « révisable » (US-1, US-2).
- [ ] Le nom proposé suit `plugin-<domaine>` ; la langue des identifiants est demandée, anglais
      par défaut.
- [ ] Seul un message explicite d'approbation passe un document en approuvé, avec la date et la
      citation ; toute autre réponse le laisse en l'état (US-3).
- [ ] Hook : un document approuvé modifié repasse en revue ; un brouillon modifié reste
      brouillon ; hors d'un projet géré, le hook est silencieux ; testé par entrées simulées
      (US-4).
- [ ] Suite d'évaluation de `frame` écrite.

### Preuve

`bash tests/run-all.sh` — tests du hook de statut vus en échec puis verts.

### Bloquée par

Phase 1.

---

## Phase 4 : Créer un plugin vert

**User stories** : US-5, US-6, US-7. **Critères de succès** : 1.

### Ce qu'on livre

`create` refuse un nom hors format ou déjà pris, refuse un dossier qui contient autre chose que le
cadrage approuvé, puis pose la charpente du modèle — manifestes, marketplace locale, licence,
harnais de tests, documents —, initialise git, et lance la suite du plugin créé et la validation
stricte.

### Critères d'acceptation

- [ ] Refus qui nomme la règle : majuscules, soulignés, préfixe `plugin-` absent (`flutter-forge`),
      domaine vide (US-5).
- [ ] Refus qui nomme l'endroit : nom présent dans la marketplace `soon`, lue par `gh api`
      (doublure en test), ou dépôt `soonlysoul/<nom>` existant (US-5, US-28).
- [ ] Dossier contenant un fichier hors cadrage : refus, dossier identique octet pour octet,
      prouvé par empreinte (US-7) ; cadrage non approuvé : refus (US-3).
- [ ] Plugin créé : sa propre suite sort en 0, la validation stricte passe sur chaque cible, sans
      aucune retouche à la main (US-6, critère 1).
- [ ] Manifeste sans e-mail ; aucun chemin personnel ni du store dans ce qui est produit.
- [ ] Suite d'évaluation de `create` écrite.

### Preuve

`bash tests/run-all.sh` — la suite de création, vue en échec puis verte, crée un plugin dans un
dossier temporaire et y lance `bash tests/run-all.sh`, qui doit sortir en 0.

### Bloquée par

Phase 3.

---

## Phase 5 : Reprise depuis le disque

**User stories** : US-34.

### Ce qu'on livre

Chaque étape des skills écrit un point de reprise : étape, commande, code de sortie, prochaine
action. `resume`, sur le modèle de recover-session, croise ce point, l'historique git et l'état du
dépôt, relance au plus le test ciblé de la dernière étape, résume en dix lignes au plus et attend
l'accord. Un hook Stop rappelle une fois de mettre à jour un point de reprise périmé.

### Critères d'acceptation

- [ ] Création interrompue (simulée) : le résumé dit ce qui est fait et ce qui reste, en dix
      lignes au plus, et propose l'étape suivante sans refaire les précédentes (US-34).
- [ ] Incohérences signalées : commit plus récent que le point de reprise, autre branche,
      fichiers modifiés non commités.
- [ ] Aucune écriture avant l'accord.
- [ ] Décision consignée : `.plugin-plugin/` est-il versionné ?
- [ ] Hook de rappel : silencieux sans dossier d'état ou si `stop_hook_active` ; un seul rappel si
      le point de reprise est plus ancien que le dernier commit ou qu'un fichier modifié.
- [ ] Suite d'évaluation de `resume` écrite.

### Preuve

`bash tests/run-all.sh` — tests du résumé et du hook de rappel vus en échec puis verts.

### Bloquée par

Phase 4.

---

## Phase 6 : Ajouter un skill avec son évaluation

**User stories** : US-8 (skill), US-9, US-10, US-11, US-12. **Critères de succès** : 4, 5.

### Ce qu'on livre

`add skill` recueille deux à quatre demandes qui doivent déclencher le skill et une ou deux qui ne
le doivent pas, en tire la suite d'évaluation, la voit échouer avant d'écrire le skill, puis passer
avec un écart positif sur le témoin. Le coût s'annonce avant chaque lancement ; un cas qui a besoin
de Bash sans bwrap est déclaré bloqué.

### Critères d'acceptation

- [ ] Vérification de chaque suite sans la lancer : `schema_version: "1.0"`, au moins un cas
      négatif, au moins un correcteur de résultat par cas, trois exécutions au moins ; une règle
      manquante produit un refus qui la nomme (US-10). Les suites écrites en phases 2 à 5 la
      passent aussi.
- [ ] En-tête et description du skill au modèle, contrôlés par un analyseur strict : forme
      plugin-flutter avec phrases de déclenchement en français, 1 536 caractères au plus, moins de
      500 lignes, aucun `$0`–`$9`.
- [ ] Annonce avant lancement : nombre de sessions, fourchette de coût, plafond (3 USD par défaut,
      modifiable), compte qui paie ; sans « oui », rien ne part (US-11).
- [ ] La commande produite porte toujours `--no-publish` et `--max-cost-usd`, jamais
      `--trust-plugin` ; le rapport reste sur le poste.
- [ ] Un cas que le témoin réussit est refusé (US-9) ; un cas qui exige Bash sans bwrap ni socat
      est « bloqué : bwrap absent », jamais « réussi » (US-12).
- [ ] Sondes consignées : la confirmation de confiance hors terminal interactif ; le compte
      annoncé par `claude auth status`, comparé au titulaire réel ; le chargement des autres
      plugins installés (flutter-forge et son skill recover-session) dans le bras témoin, traces
      gardées par `--keep-temp`.
- [ ] Premier passage réel, sur accord, d'un skill d'essai qui s'évalue sans Bash : rouge avant le
      skill, vert avec Δ > 0 ; sorties consignées (critères 4, 5).

### Preuve

`bash tests/run-all.sh` pour la partie sans quota ; puis le passage réel annoncé et accordé, sortie
rouge puis verte avec l'écart positif.

### Bloquée par

Phase 4.

---

## Phase 7 : Ajouter un hook testé sans session

**User stories** : US-8 (hook), US-14, US-15. **Critères de succès** : 4.

### Ce qu'on livre

`add hook` fixe l'événement, le filtre et le mode (fail-open ou fail-closed), câble `hooks.json` en
forme exec, pose le script et son test d'entrées simulées. Le test échoue pour la bonne raison,
puis passe. Avant l'écriture, `add hook` avertit que le hook s'appliquera à toutes les sessions
une fois le plugin installé pour le compte.

### Critères d'acceptation

- [ ] `hooks.json` : forme exec, chemin par `${CLAUDE_PLUGIN_ROOT}`, `timeout` déclaré,
      `onFailure` cohérent avec le mode, script existant.
- [ ] Script produit : `#!/usr/bin/env bash`, variables entre guillemets, raison sur stderr, exit 2
      pour bloquer, blocage sur JSON illisible et jq absent en mode fail-closed ;
      `shellcheck -S warning` passe (sauté s'il est absent).
- [ ] Le test d'entrées simulées échoue sur le squelette pour la bonne raison, puis passe ; les
      deux sorties consignées (US-14, critère 4).
- [ ] L'avertissement de portée s'affiche avant l'écriture et figure dans INSTALLATION (US-15).
- [ ] Le hook est inerte hors de son contexte, et ne suppose aucun ordre entre hooks.

### Preuve

`bash tests/run-all.sh` — un plugin créé en dossier temporaire reçoit un hook ; sa suite montre le
test du hook en échec, puis vert.

### Bloquée par

Phase 4.

---

## Phase 8 : Ajouter un agent aux outils déclarés

**User stories** : US-8 (agent), US-13. **Critères de succès** : 4.

### Ce qu'on livre

`add agent` produit un agent dont l'en-tête strict déclare ses outils et son modèle, sans `Agent`,
avec le rapport à format fixe. Un agent qui écrit reçoit ses limites par un garde de portée.

### Critères d'acceptation

- [ ] L'analyseur strict refuse les sept formes cassées relevées par plugin-flutter : crochet
      ouvert, « : » non cité, liste YAML, clé en double, guillemet isolé, en-tête non refermé ou
      non ouvert.
- [ ] `tools` présent, outils connus, jamais `Agent` ; un relecteur n'a ni Write ni Edit (US-13).
- [ ] Nom de 3 à 50 caractères, commençant et finissant par une lettre ou un chiffre ; description
      « Use this agent when … ; not for … » de 200 à 1 000 caractères ; corps en responsabilités,
      démarche et format de sortie, avec STATUS / FILES_CHANGED / COMMANDS_RUN / OPEN_QUESTIONS.
- [ ] Un agent qui écrit a ses dossiers d'écriture et sa liste blanche Bash imposés par le garde de
      portée, inerte hors des agents du plugin.
- [ ] Test vu en échec (agent absent), puis vert (critère 4).

### Preuve

`bash tests/run-all.sh` — tests d'en-tête et de portée vus en échec puis verts, sur un plugin créé.

### Bloquée par

Phase 4.

---

## Phase 9 : Déclarer un serveur MCP existant ; refuser le hors-périmètre

**User stories** : US-8 (MCP), US-16. **Critères de succès** : 4.

### Ce qu'on livre

`add mcp` déclare un serveur existant — local par un lanceur cité par `${CLAUDE_PLUGIN_ROOT}`, ou
distant — sans écrire son code ni rien installer. Toute demande hors périmètre est refusée avec sa
raison et le déclencheur qui la rouvrirait.

### Critères d'acceptation

- [ ] `.mcp.json` valide ; variables de l'utilisateur en `${VAR}`, aucune valeur secrète ; serveur
      distant en HTTPS ou WSS ; variables documentées dans le README.
- [ ] Aucune installation impérative (`bun install`, `npm install`, `pip install`…) dans ce qui
      est produit.
- [ ] Refus motivés, chacun avec son déclencheur : code d'un serveur MCP et channel (« premier
      plugin qui a besoin d'un système sans ligne de commande, ou d'un channel »), serveur de
      langage (« v0.2 »), style de sortie, commande classique, option de plugin, dépendance entre
      plugins (US-16).
- [ ] La déclaration rappelle qu'un skill qui dépend du serveur a besoin d'une doublure dans
      `evals/mocks/` pour être évalué.
- [ ] Test vu en échec puis vert (critère 4).

### Preuve

`bash tests/run-all.sh` — tests de déclaration et de refus vus en échec puis verts.

### Bloquée par

Phase 4.

---

## Phase 10 : Plugins existants — écarts au modèle, ajout sans toucher au métier

**User stories** : US-17, US-18.

### Ce qu'on livre

`check` liste les écarts d'un plugin au modèle sans rien modifier. Sur un plugin du modèle, `add`
ajoute un composant sans toucher au contenu métier.

### Critères d'acceptation

- [ ] plugin-flutter (copie de lecture) : aucun écart.
- [ ] plugin-nixos : ses écarts listés, dont la forme des hooks, l'arborescence des hooks et le
      harnais ; ancien flutter-forge : nom hors format ; aucun fichier modifié, prouvé par
      empreintes (US-18).
- [ ] Contrôles repris de plugin-validator : fichiers parasites (`node_modules`, `.DS_Store`),
      identifiants écrits en clair, README et LICENSE présents.
- [ ] Ajout d'un composant à une copie de plugin-flutter : le diff ne touche que le composant, son
      câblage, la version et le CHANGELOG ; la suite d'origine reste à 100 % (US-17).
- [ ] Suite d'évaluation de `check` écrite.

### Preuve

`bash tests/run-all.sh` ; puis `check` sur les trois plugins réels, sorties consignées.

### Bloquée par

Phases 6, 7, 8 et 9.

---

## Phase 11 : Répétition de publication

**User stories** : US-22, US-23, US-24, US-25, US-28, US-29. **Critères de succès** : 9.

### Ce qu'on livre

`release` en répétition vérifie, calcule, rédige et annonce chaque geste, sans rien envoyer.

### Critères d'acceptation

- [ ] Refus si la suite ou la validation stricte n'est pas verte, ou si le dépôt a des
      changements non enregistrés (US-23).
- [ ] Version proposée selon la nature du changement ; entrée de CHANGELOG rédigée ; étiquette
      vérifiée par `claude plugin tag --dry-run` (US-22).
- [ ] État de la marketplace lu sur GitHub par `gh api` (US-28).
- [ ] Coût en contexte par composant, par `claude plugin details` ; alerte au-delà de 1 000 tokens
      permanents (US-25, critère 9).
- [ ] Liste ordonnée des gestes, chacun avec sa commande exacte ; aucun n'est exécuté, et les
      journaux des doublures `gh` et `git push` restent vides (US-24).
- [ ] Commande d'installation ou de mise à jour à lancer soi-même (US-29).
- [ ] Suite d'évaluation de `release` écrite.

### Preuve

`bash tests/run-all.sh` — répétition sur un plugin créé, contre les doublures : la sortie liste
les gestes, les journaux des doublures sont vides.

### Bloquée par

Phase 4.

---

## Phase 12 : Publication sous accord

**User stories** : US-20, US-21, US-26, US-27. **Critères de succès** : 6.

### Ce qu'on livre

Les gestes réels — création du dépôt, push, PR de marketplace, push de l'étiquette, montage en
sous-module —, chacun annoncé, exécuté sur un « oui » littéral contrôlé par hook, journalisé et
reprenable. Tout se teste contre des dépôts nus locaux et une doublure de `gh` : aucun geste vers
le vrai GitHub dans cette phase.

### Critères d'acceptation

- [ ] Le garde refuse tout geste GitHub sans accord ; un « oui » littéral laisse passer une seule
      fois la commande annoncée ; « ok », « oui mais… » ou le silence valent refus (US-20,
      critère 6).
- [ ] Sonde consignée : entrée de `UserPromptSubmit` en 2.1.296, et comportement dans l'extension
      VSCode. Si le mécanisme ne tient pas, la décision g est révisée avant la suite.
- [ ] Le garde est inerte hors d'un dépôt de plugin du modèle ou de la marketplace, et ne dépend
      d'aucun autre hook.
- [ ] Marketplace : une branche et une PR, jamais de commit direct sur `main`, jamais de fusion
      (US-21).
- [ ] Coupure simulée en cours de publication : le rapport nomme le geste échoué, ce qui est fait
      et la commande qui reprend ; la reprise ne refait aucun geste fait (US-27).
- [ ] Montage en sous-module dans un dépôt hôte, épinglé sur l'étiquette (US-26).
- [ ] Gestes destructifs refusés : suppression de dépôt, push forcé, réécriture d'historique,
      retrait de plugin, fusion.

### Preuve

`bash tests/run-all.sh` — publication complète contre des dépôts nus locaux : journal des
accords, journal des gestes et état des dépôts nus contrôlés.

### Bloquée par

Phase 11.

---

## Phase 13 : Reconstruction de plugin-flutter

**User stories** : US-19. **Critères de succès** : 2, volet plugin-flutter.

### Ce qu'on livre

plugin-flutter reconstruit dans `build/` : charpente produite par plugin-plugin, contenu métier
importé tel quel depuis une copie de lecture. Sa propre suite et la validation stricte y passent.

### Critères d'acceptation

- [ ] La suite d'origine de plugin-flutter passe à 100 % dans la reconstruction (critère 2).
- [ ] Validation stricte sur chaque cible.
- [ ] Original intact : HEAD et `git status --porcelain` identiques avant et après.
- [ ] Chaque écart entre la charpente produite et l'originale se corrige dans plugin-plugin, jamais
      à la main dans la reconstruction, et se consigne.

### Preuve

La suite d'origine lancée dans la reconstruction : exit 0, comptes de réussis et d'échoués
consignés.

### Bloquée par

Phase 10.

---

## Phase 14 : Réécriture de plugin-nixos au modèle

**User stories** : US-18, US-19. **Critères de succès** : 2, volet plugin-nixos.

### Ce qu'on livre

plugin-nixos réécrit au modèle dans `build/` : contenu métier importé tel quel, sauf ce que le
modèle impose — hooks en forme exec, arborescence `hooks/scripts/`, harnais de tests du modèle.
C'est un test de plugin-plugin : jamais publié.

### Critères d'acceptation

- [ ] Les écarts listés par `check` sur l'original (phase 10) forment la liste de travail ; sur la
      réécriture, `check` n'en relève plus aucun (critère 2).
- [ ] Suite portée au harnais du modèle : chaque cas d'origine a son équivalent, comptes par suite
      consignés avant et après ; elle sort en 0 (critère 2).
- [ ] Validation stricte sur chaque cible.
- [ ] Le script appelé par les skills est rangé selon la décision a ; le serveur MCP est déclaré
      comme en phase 9.
- [ ] Original intact : HEAD et `git status --porcelain` identiques, dans le clone (aucun
      sous-module ne cite plugin-nixos sur ce poste).

### Preuve

La suite portée lancée dans la réécriture, exit 0, et `check` à zéro écart.

### Bloquée par

Phase 10.

---

## Phase 15 : Plugin témoin de bout en bout

**User stories** : toutes, en usage réel. **Critères de succès** : 3, 4, 5.

### Ce qu'on livre

Un plugin témoin — un skill, un agent, un hook — construit par plugin-plugin du cadrage à la
répétition de publication, en session interactive, sans autre intervention que les accords
demandés.

### Critères d'acceptation

- [ ] Cadrage approuvé avant tout fichier ; création verte ; un skill, un agent et un hook
      ajoutés, chacun avec sa sortie rouge puis verte (critères 3, 4).
- [ ] Le skill du témoin s'évalue sans Bash : au moins un cas positif et un négatif, trois
      exécutions par cas, écart positif sur le témoin sans plugin ; coût annoncé et accordé avant
      lancement (critère 5).
- [ ] Répétition de publication complète, rien d'envoyé.
- [ ] Aucune retouche à la main ; chaque intervention de Soon est un accord demandé, et compté.
- [ ] Preuve de chargement : `system/init` liste le plugin, sans `plugin_errors`.

### Preuve

Le journal de la session (accords, gestes, sorties de tests), la sortie de l'évaluation et celle
de la répétition, consignés.

### Bloquée par

Phases 3 à 12.

---

## Phase 16 : Clôture de 0.1.0, puis plugin-plugin publie lui-même sa 0.1.1

**User stories** : US-30. **Critères de succès** : 7, 6, 9.

### Ce qu'on livre

plugin-plugin 0.1.0 clôturé : une relecture unique de ses skills par `plugin-dev:skill-reviewer`,
constats traités, étiquette locale `plugin-plugin--v0.1.0`. Puis plugin-plugin publie lui-même sa
0.1.1 sur la vraie marketplace, chaque geste après un « oui ».

### Critères d'acceptation

- [ ] Relecture : constats bloquants corrigés, tests relancés ; plugin-dev reste une aide de
      développement, pas une dépendance.
- [ ] Coût permanent sous 1 000 tokens (critère 9).
- [ ] 0.1.1 : version et CHANGELOG à jour, étiquette `plugin-plugin--v0.1.1` présente sur GitHub
      (critère 7).
- [ ] Dépôt `soonlysoul/plugin-plugin` créé, push, PR vers `soonlysoul/claude-plugins` — chacun sur
      un « oui » enregistré (critère 6) ; PR fusionnée par Soon.
- [ ] Après la fusion, la commande d'installation est donnée ; sur un appareil, Soon installe ou
      met à jour, et `claude plugin list` montre plugin-plugin 0.1.1 (critère 7).

### Preuve

Journal des accords et des gestes ; `gh api` montrant le dépôt, l'étiquette et la PR fusionnée ;
sortie de `claude plugin list` sur l'appareil.

### Bloquée par

Phases 13, 14 et 15.

---

## Phase 18 : Descriptions et documents tenus à chaque publication

**User stories** : US-35, US-36, US-37. **Critères de succès** : 10, 6, 9.

La phase 17, demande de Soon hors plan (plugin-nixos réécrit et publié), est consignée dans
PROGRESS.md.

### Ce qu'on livre

`release` lit, sans rien envoyer, la description du dépôt GitHub, l'entrée et le README de la
marketplace `soon`, et les compare à la description du `plugin.json` (décision h). `release-write`
écrit aussi la version dans le README et la description dans la marketplace locale. `publish`
exécute les gestes d'alignement comme les autres, sous accord, reprenables. Le skill `release`
et les documents de plugin-plugin le disent.

### Critères d'acceptation

- [ ] Refus à la répétition : description absente ou au-delà de 350 caractères ; README sans
      ligne `Version **X.Y.Z**`, ou qui ne nomme pas un composant, nommé (US-36).
- [ ] `release-write` écrit la version dans le README et la description dans la marketplace
      locale, dans le commit de version ; déjà écrites, rien ne change (US-36, US-35).
- [ ] Description GitHub divergente : un geste `gh repo edit … --description`, après le push de
      l'étiquette ; un dépôt créé la reçoit par `gh repo create` (US-35).
- [ ] Plugin listé dont l'entrée ou la ligne du README diverge : branche, entrée et ligne
      réécrites, commande d'installation ajoutée si elle manque, commit, push, PR ; un plugin
      nouveau reçoit la ligne et la commande dans la PR d'ajout. Le reste du README est intact
      (US-35, critère 6).
- [ ] Rien à publier depuis l'étiquette, des descriptions divergentes : un alignement — ni
      version, ni CHANGELOG, ni étiquette —, annoncé et lancé étape par étape ; tout aligné :
      refus, « rien à publier » (US-37).
- [ ] Une branche de marketplace déjà sur GitHub est refusée à la répétition, la PR ouverte
      nommée.
- [ ] Coupure simulée pendant un alignement : la reprise ne refait aucun geste fait (US-27).
- [ ] Coût permanent de plugin-plugin sous 1 000 tokens (critère 9).
- [ ] plugin-plugin publie sa version suivante par ce chemin ; plugin-nixos et plugin-flutter
      sont alignés, chaque geste sur un « oui » ; PR fusionnées par Soon (critère 10).

### Preuve

`bash tests/run-all.sh` — répétition, publication et alignement contre des dépôts nus locaux et
la doublure de `gh` : la marketplace et le README produits, le journal des gestes. Puis `gh api`
sur les trois dépôts et sur `soonlysoul/claude-plugins` après les fusions.

### Bloquée par

Phase 16 ; pour plugin-flutter, des entrées `.plugin-plugin/` dans son `.gitignore`, que
`publish` exige.
