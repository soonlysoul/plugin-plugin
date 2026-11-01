# Modèle de plugin — plugin-plugin

2026-10-23 · Soon

**Statut : APPROUVÉ** le 2026-11-01 (« Oui »).

Ce document est la seule source du modèle de plugin de plugin-plugin (décision i du plan,
US-38). `check` en vérifie les règles, `create` et `rebuild` en produisent la charpente, `add` y
range chaque composant. Aucun plugin existant n'en est la référence, car un plugin change avec le
temps : chaque règle tient par sa raison — un fait de la base `scripts/facts/facts.json`, que
`reaudit` désigne à revérifier après chaque mise à jour de Claude Code, ou une convention de Soon.
Mesures de référence : Claude Code 2.1.296.

Changer une règle, c'est amender ce document, qui repasse alors en revue, le faire approuver, puis
changer `check` et son test. `tests/static/test_model.sh` refuse une catégorie d'écart sans règle,
une règle sans contrôle ni raison, et un fait cité absent de la base.

Jusqu'au 2026-10-23, le modèle était un plugin existant (plan, décision i) ; ses règles sont
reprises ici telles quelles, chacune justifiée pour elle-même.

Amendé le 2026-10-26, à la demande de Soon, sur deux constats de la construction d'un plugin :
un script de `scripts/` s'ajoute par `add`, avec son test, et se construit avant le composant
qui l'appelle sans faire rougir la suite, mais ne se publie pas sans lui (R6, R9, R12, R14) ; un
garde fail-closed ne bloque que dans son contexte, comme le squelette de `add-hook` depuis
plugin-plugin 0.1.4 (R7).

Amendé le 2026-11-01, à la demande de Soon : un skill pose ses choix et ses accords par
`AskUserQuestion` quand l'outil est offert, la recommandation en tête pour un choix, « Non » en
tête pour un accord ; en texte sinon (R10). Mesures de Claude Code 2.1.316, sonde de la phase 25.

## Règles

### R1 — Le nom `plugin-<domaine>`

Le plugin s'appelle `plugin-<domaine>`, en minuscules et tirets : le même nom dans `plugin.json`,
dans sa marketplace locale et pour son dépôt.

- **Contrôle** : `[manifeste]` ; `pp.sh check-name` à la création.
- **Raison** : convention de Soon — un nom choisi trop vite coûte un renommage après publication.
  Claude Code n'exige que le kebab-case.
- **Faits** : `manifest-name-only-required`

### R2 — Un dépôt dédié, le plugin à sa racine

Le plugin vit seul dans le dépôt `soonlysoul/<nom>`, à sa racine ; `homepage` et `repository`
désignent ce dépôt.

- **Contrôle** : `[manifeste]`
- **Raison** : un dépôt par plugin porte sa version, ses étiquettes `{nom}--v{version}` et sa
  source dans la marketplace `soon`. Un dépôt encore inexistant n'empêche ni la validation stricte
  ni le chargement : `homepage` s'écrit dès la création.
- **Faits** : `marketplace-soon-entry-format`, `plugin-tag-command`,
  `homepage-missing-repo-loads`, `manifest-homepage-valid-url`

### R3 — Le manifeste `plugin.json`

`name`, `version` en SemVer, `description`, `author` réduit à `{"name": "Soon"}`, sans e-mail,
`license` MIT, `homepage` égal à `repository`, `keywords` facultatif ; aucun autre champ.

- **Contrôle** : `[manifeste]`
- **Raison** : la validation stricte échoue sur un champ manquant ou inconnu ; la version fige les
  installations distantes jusqu'à son changement, d'où SemVer. L'e-mail ne sort pas du poste, et
  MIT est la licence de Soon (conventions de Soon).
- **Faits** : `manifest-missing-fields-warn`, `manifest-unknown-field`,
  `manifest-version-pins-remote`, `plugin-init-template-unsafe`

### R4 — La marketplace locale

`.claude-plugin/marketplace.json` : `owner.name` « Soon », une seule entrée `"source": "./"`, du
même nom que le manifeste, sans `version`.

- **Contrôle** : `[manifeste]`
- **Raison** : elle rend le dépôt installable et validable seul, et sa validation couvre
  `plugin.json` ; une `version` répétée fait avertir le validateur, `plugin.json` seul la porte.
- **Faits** : `marketplace-required-fields`, `marketplace-source-same-name`,
  `marketplace-no-version`, `validate-root-covers-plugin`

### R5 — Les fichiers de la racine

Une LICENSE MIT au nom de Soon, un README, un CHANGELOG en français (Keep a Changelog) qui a une
entrée pour la version du manifeste, un PROGRESS, un ARCHITECTURE (à la racine ou dans `docs/`),
`docs/INSTALLATION.md`, `docs/USER_GUIDE.md`, `docs/SECURITY.md`, `docs/TROUBLESHOOTING.md`, un
`.gitignore` ; aucun CLAUDE.md.

- **Contrôle** : `[racine]`
- **Raison** : un plugin se mène sur plusieurs sessions et se publie par versions ; son état, ses
  décisions et son journal vivent dans son dépôt (convention de Soon). Un CLAUDE.md à la racine
  d'un plugin n'est pas chargé, et fait avertir.
- **Faits** : `plugin-root-claude-md`

### R6 — L'arborescence

À la racine, seuls `skills/`, `agents/`, `hooks/`, `scripts/`, `templates/`, `tests/`, `docs/`,
`evals/`, les fichiers de R5 et les entrées cachées (`.claude-plugin/`, `.mcp.json`,
`.gitignore`…). `scripts/` accueille un outil qu'appellent les composants — un ou plusieurs
skills, un agent, un script de hook, ou la déclaration d'un serveur MCP dont il est le lanceur
(R13) — (décision a du plan).

- **Contrôle** : `[arborescence]`
- **Raison** : une installation copie tout le dossier du plugin ; un dossier qui ne sert à aucun
  composant y serait copié pour rien.
- **Faits** : `directory-marketplace-install-copies-ignored`

### R7 — La forme des hooks

`hooks/` ne contient que `hooks.json`, `agent-scope.json` et `scripts/`. Chaque hook est en forme
exec : `"type": "command"`, `"command": "bash"`, le script seul dans `args`, cité par
`${CLAUDE_PLUGIN_ROOT}`, `timeout` déclaré. Un garde fail-closed, en-tête `# Fail-closed`, a
`onFailure: block` : il teste d'abord son contexte, avec les seuls builtins de bash, et hors de
lui sort en 0, même sur une erreur (R8) ; dans son contexte, il bloque par exit 2, sur sa règle
comme sur une erreur interne (jq absent, entrée illisible). Un hook fail-open, en-tête
`# Fail-open`, a `onFailure: continue` et sort toujours en 0. Sur Stop et SubagentStop,
`onFailure` manque. Chaque script de `hooks/scripts/` existe et est câblé dans `hooks.json`.

- **Contrôle** : `[arborescence des hooks]`, `[forme des hooks]`, `[hooks]` — forme exec,
  `timeout`, `onFailure` déclaré hors Stop et SubagentStop et accordé à l'en-tête du script :
  `# Fail-closed` exige `block`, `# Fail-open` exige `continue`. `check` ne lit pas le
  comportement de part et d'autre du contexte : le test du hook sur entrées simulées le prouve
  (R14), et celui qu'écrit `add-hook` le prouve d'office des deux côtés.
- **Raison** : la forme exec se passe de shell, de guillemets et de bit exécutable. Sans
  `onFailure: block`, un garde qui plante, introuvable ou trop lent laisse passer ; un exit 1 ne
  bloque pas. `onFailure` s'applique là où le script n'a plus la main — introuvable, tué, hors
  délai —, donc dans toutes les sessions : le contexte se teste en premier et vite, sans
  dépendre d'aucune commande. Installé pour le compte, un garde qui bloquerait sur une erreur
  hors de son contexte bloquerait toutes les sessions. Le validateur n'inspecte pas les
  scripts : le contrôle le fait.
- **Faits** : `hook-exec-form`, `hook-onfailure-block`, `hook-exit-1-not-blocking`,
  `hook-block-exit-2`, `validator-ignores-hooks`, `hooks-envelope`, `stop-no-matcher`,
  `hooks-scope-all-sessions`

### R8 — La portée des hooks

Un hook reste inerte hors de son contexte et ne dépend d'aucun autre : les hooks d'un même
événement tournent en parallèle, dans un ordre quelconque.

- **Contrôle** : aucun de `check` ; le test du hook sur entrées simulées le prouve (R14), et `add`
  avertit de la portée avant d'écrire.
- **Raison** : installé pour le compte, un hook se déclenche dans toutes les sessions, que les
  skills du plugin servent ou non ; il ne coûte rien en contexte.
- **Faits** : `hooks-scope-all-sessions`, `plugin-details-hooks-free`

### R9 — Les scripts

Chaque script shell — sous `scripts/`, `hooks/scripts/` ou leur `lib/`, ou un outil sans
extension de `scripts/` — passe `bash -n` et commence par `#!/usr/bin/env bash`, sauf une
bibliothèque de `lib/`. Variables entre guillemets, raison d'un refus sur stderr. Un script de
`scripts/` que `add` ajoute part d'un squelette à cette forme, qui refuse un appel inconnu par
son usage sur stderr, exit 1 ; le premier cas de son test vérifie ce refus, ou celui qui le
remplace (R14).

- **Contrôle** : `[scripts]` ; pour un script ajouté par `add`, le premier cas de son test.
- **Raison** : NixOS n'a pas de `/bin/bash` ; un script qui ne se lit pas casse son hook sans
  bruit. L'appelant d'un script lit son code de sortie : un refus en 1, sa raison sur stderr,
  ne se confond pas avec un résultat.
- **Faits** : `nixos-no-bin-bash`

### R10 — Les skills

Un `SKILL.md` par dossier de `skills/`. En-tête strict : une ligne `clé: valeur` par clé, refermé
par `---`, clés connues, jamais `allowed-tools`, `name` égal au dossier, `description` présente ;
description et `when_to_use` réunis sous 1 536 caractères. SKILL.md sous 500 lignes, détails dans
`reference/`, aucun `$0` à `$9` ; un point de reprise s'écrit à chaque étape.

Un choix entre des options connues se pose par `AskUserQuestion`, une question par appel : de 2 à
4 options, la recommandée en tête, son libellé fini par « (Recommandé) », sa raison dans sa
description. Un accord aussi — approbation, geste, commit, dépense : « Non » puis « Oui », aucune
option recommandée, `answers` jamais rempli par Claude ; seul « Oui », choisi ou tapé, sans note
jointe, vaut accord. Une question ouverte se pose en texte. Sans l'outil — un sous-agent,
`claude -p` sans hôte de permission —, toute question se pose en texte, puis le skill s'arrête ;
un « oui » tapé vaut le même accord.

- **Contrôle** : `[skills]`
- **Raison** : au-delà de 1 536 caractères, la description est tronquée ; le corps reste en
  contexte après l'invocation ; `allowed-tools` accorde sans restreindre. `AskUserQuestion` montre
  les options et la recommandation sans rien à retaper, et rend la réponse structurée ; elle ne
  passe pas par UserPromptSubmit, et un garde d'accord la lit en PostToolUse. Sur un accord,
  Claude ne pousse pas : « Non » en tête. Claude peut remplir `answers` lui-même, et un autre hôte
  que la session interactive peut retenir cette réponse sans rien afficher. Échap ne laisse
  aucune trace aux hooks : l'absence de réponse n'est pas un accord. Un sous-agent et `-p` sans
  hôte n'ont pas l'outil.
- **Faits** : `skill-fields`, `skill-description-limit-1536`, `skill-body-stays-in-context`,
  `skill-allowed-tools-grants`, `argument-hint-yaml-list`, `askuserquestion-headless`,
  `subagent-no-askuserquestion`, `askuserquestion-interactive`, `askuserquestion-limits`,
  `askuserquestion-answer-no-userpromptsubmit`, `askuserquestion-posttooluse-answers`,
  `askuserquestion-escape-no-hook`, `askuserquestion-claude-prefill`

### R11 — Les agents

En-tête strict : `name` égal au fichier, `description`, `tools`, `model`, `color`. `tools` est
toujours déclaré, chaque outil connu, jamais `Agent` ; un relecteur (`*review*`) n'a ni Write ni
Edit ; le rapport porte STATUS, FILES_CHANGED, COMMANDS_RUN et OPEN_QUESTIONS. Un agent qui écrit
ou lance Bash est tenu par un garde de portée : un hook PreToolUse qui lit `agent_type`.

- **Contrôle** : `[agents]`
- **Raison** : sans `tools`, ou avec un en-tête illisible, un agent reçoit tous les outils, sans
  message, et le validateur accepte un en-tête cassé. Un agent ne restreint pas Bash par motif :
  seul un garde le peut.
- **Faits** : `agent-tools-omitted-inherits-all`, `agent-broken-frontmatter-all-tools`,
  `validator-accepts-broken-agent-frontmatter`, `agent-bash-pattern-restriction`,
  `agent-type-in-hooks`, `agent-model-values`

### R12 — Les chemins

Tout chemin cité par `${CLAUDE_PLUGIN_ROOT}/…` dans un skill, un agent ou `.mcp.json` existe ;
chaque fichier de `templates/` et d'un dossier de skill est cité. Chaque script de `scripts/`,
hors de `lib/`, est cité par `${CLAUDE_PLUGIN_ROOT}/…` dans un skill, un agent, `hooks.json`,
un script de `hooks/scripts/` ou `.mcp.json`. Tant que rien ne le cite, il est en
construction : il porte la marque `# CALLER: <fichier>`, qui nomme le composant qui le citera ;
la suite de son plugin le dit sauté, et `release` le refuse. Aucun interpréteur à chemin fixe,
aucun chemin personnel (`/home/…`, `/Users/…`) ni du store.

- **Contrôle** : `[chemins]` ; la citation d'un script, par `tests/static/test_paths.sh` dans la
  suite du plugin — cité, réussi ; marqué, sauté, l'appelant nommé ; ni l'un ni l'autre, échec —
  et par la répétition de `release`, qui refuse un script que rien ne cite. `check` ne la relève
  pas : `add` exige un plugin sans écart, et doit pouvoir ajouter l'appelant d'un script en
  construction.
- **Raison** : la racine d'un plugin installé change à chaque mise à jour et d'un poste à
  l'autre ; seul `${CLAUDE_PLUGIN_ROOT}` la désigne, et seul SKILL.md est substitué. Un hook la
  reçoit aussi dans son environnement : l'outil qu'il appelle depuis son script y est cité. Un
  fichier jamais cité ne sert à rien, et ne se publie pas. Un script se construit et se teste
  avant que son appelant le cite : un rouge attendu pendant toute sa construction s'apprend à
  ignorer et cache une vraie régression ; la marque déclare l'attente sans la cacher.
- **Faits** : `plugin-root-changes-on-update`, `plugin-root-var-skills`, `plugin-root-var-hooks`,
  `annexes-not-substituted`

### R13 — La déclaration d'un serveur MCP

`.mcp.json`, sous `mcpServers` : un serveur local lancé par `bash` et un lanceur
`${CLAUDE_PLUGIN_ROOT}/scripts/<nom>.sh`, un serveur distant en HTTPS ou WSS. Rien ne s'installe
au démarrage ; chaque valeur de l'environnement s'écrit `${VAR}` ; aucun secret en clair.
plugin-plugin déclare un serveur existant ; il n'en écrit pas le code (exclusion `mcp-code`).

- **Contrôle** : `[MCP]`
- **Raison** : le validateur tolère un champ inconnu dans l'entrée d'un serveur ; la forme du
  lanceur, l'installation et le secret se contrôlent donc par script. Une installation au
  démarrage contredit un poste dont toute la configuration est déclarée (convention de Soon).
- **Faits** : `mcp-declaration-forms`, `mcp-validated-with-manifest`,
  `mcp-server-unknown-field-tolerated`, `plugin-init-template-unsafe`

### R14 — Le harnais de tests

`tests/run-all.sh`, qui sort en 0, 1 ou 2 ; `tests/lib.sh` ; au moins un test dans
`tests/static/` ; aucun `tests/test_*.sh` hors de `tests/static/` et `tests/hooks/` ; chaque
script de `hooks/scripts/` a son test sur entrées simulées, `tests/hooks/test_<nom>.sh`. Un
script de `scripts/` ajouté par `add` a le sien, `tests/static/test_script_<nom>.sh`, qui le
lance par `bash`, sur des doublures. La suite est déterministe — bash et jq, sans réseau, sans
session, sans quota — et lance la validation stricte.

- **Contrôle** : `[harnais]` ; le test d'un script s'écrit avec lui, par `add` : `check` ne
  l'exige pas d'un script écrit autrement, qui se teste à sa façon (`pp.sh`, par plusieurs
  suites).
- **Raison** : un composant se prouve rouge puis vert sans consommer de quota (convention de
  Soon) ; le validateur ne voit ni un en-tête d'agent cassé ni un script de hook absent.
  `tests/static/` est le dossier que lance tout harnais du modèle, que plugin-plugin l'ait créé
  ou non.
- **Faits** : `validate-exit-codes`, `validator-ignores-hooks`,
  `validator-accepts-broken-agent-frontmatter`

### R15 — L'hygiène

Aucun fichier parasite (`node_modules`, `.DS_Store`, `Thumbs.db`, `*.swp`) ; aucun identifiant en
clair — clé privée, jetons GitHub, Anthropic, OpenAI, AWS ou Slack.

- **Contrôle** : `[hygiène]`
- **Raison** : ce que le dépôt porte est publié et copié à l'installation ; une fuite de secret ne
  se rattrape pas.
- **Faits** : `directory-marketplace-install-copies-ignored`

### R16 — Le coût en contexte

Moins de 1 000 tokens permanents, mesurés par `claude plugin details`. Au-delà, la suite de
plugin-plugin échoue, celle d'un plugin produit alerte.

- **Contrôle** : `tests/run-all.sh`, étape « coût en contexte permanent ».
- **Raison** : chaque description de skill et d'agent est en contexte dans toutes les sessions ;
  les hooks ne coûtent rien.
- **Faits** : `plugin-details-cost`, `plugin-details-per-component`,
  `skill-description-always-loaded`, `plugin-details-hooks-free`

### R17 — Les langues

Code, identifiants et fichiers du plugin en anglais par défaut, choisis au cadrage, plugin par
plugin ; messages et documents en français.

- **Contrôle** : aucun ; tranché au cadrage (`frame`) et écrit dans le PRD du plugin.
- **Raison** : convention de Soon.

### R18 — Le style des composants ajoutés

Un skill que plugin-plugin ajoute porte `argument-hint` et `when_to_use`, et une description
« <ce que fait le skill>. Use when … ; not for … » qui cite quelques phrases de déclenchement en
français. Un agent ajouté est décrit « Use this agent when … ; not for … », en 200 à 1 000
caractères, et son corps a les sections `## Responsibilities`, `## Approach` et
`## Output format`.

- **Contrôle** : `tests/headers.sh` (`skill_style_errors`, `agent_style_errors`), dans le test du
  composant ; jamais imposé au contenu d'un plugin que plugin-plugin n'a pas écrit.
- **Raison** : une description qui dit quand se déclencher et quand ne pas le faire se prouve par
  un cas positif et un cas négatif d'évaluation ; elle est en contexte dans toutes les sessions.
- **Faits** : `skill-description-always-loaded`, `skill-command-name`

## Exclusions

Ce que `pp.sh out-of-scope` refuse, avec la raison et ce qui le rouvrirait.

- **`mcp-code`** — écrire le code d'un serveur MCP. Ce code est du métier : un langage, des
  dépendances et des tests propres au serveur, hors de la charpente ; plugin-plugin déclare un
  serveur existant (R13). Rouvert au premier plugin qui a besoin d'un système sans ligne de
  commande (PRD, « À venir »).
- **`channel`** — un channel exige le code d'un serveur MCP écrit pour le plugin. Rouvert avec
  `mcp-code`.
- **`lsp`** — la déclaration d'un serveur de langage, laissée hors de la v0.1 pour la garder
  petite. Rouvert en v0.2, où elle est prévue.
- **`output-style`** — un style de sortie ne se prouve qu'en session : aucun test déterministe ne
  le couvre, et aucun besoin ne l'a demandé. Rouvert par une révision du PRD, sur un besoin réel.
- **`command`** — une commande classique (`commands/`) est une forme ancienne, qu'un skill
  remplace : il s'invoque déjà par `/<plugin>:<skill>`. Rouvert : jamais.
- **`plugin-option`** — compte, marketplace et langue des messages restent écrits en dur (PRD).
  Rouvert par une révision du PRD, le jour où un plugin doit se régler par utilisateur.
- **`plugin-dependency`** — un plugin du modèle s'installe et fonctionne seul. Rouvert par une
  révision du PRD, quand un plugin ne peut pas fonctionner sans un autre.

## Écarté du modèle

Des formes que le modèle n'emploie pas, sans refus de `pp.sh` : `check` ne les relève pas, `add`
ne les écrit pas.

- **Hooks à prompt** : non déterministes, ils coûtent du quota à chaque appel et ne se testent pas
  sans session. Rouverts si un contrôle ne s'exprime pas en script.
- **`version` dans l'en-tête d'un skill** : ce n'est pas un champ de Claude Code.
- **Agent valideur** : la conformité se contrôle par script, avec `check`.
- **Réglages `.claude/<plugin>.local.md`** : les options de plugin sont exclues, et Claude Code
  protège l'écriture de ses fichiers de configuration sous `.claude/`.
- **Scripts utilitaires de plugin-dev** : périmés (`#!/bin/bash`, `matcher` sur Stop,
  `tool_result` au lieu de `tool_response`) et sans tests.
