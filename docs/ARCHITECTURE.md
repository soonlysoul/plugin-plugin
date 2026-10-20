# Architecture — plugin-plugin

2026-10-20 · Soon · PRD : [PRD.md](PRD.md) · Plan : [PLAN.md](PLAN.md)

**Statut : REVUE** — approuvé le 2026-10-20, modifié depuis : à réapprouver.

Ce document décrit plugin-plugin tel qu'il est construit à la clôture de 0.1.0. Les décisions qui le fondent — principes, modèle de plugin, tests, évaluations, publication, ré-audit, ce qui est écarté et ce qui le rouvrirait — sont celles de la section « Décisions architecturales » du plan, approuvé le 2026-10-19 ; elles ne sont pas recopiées ici.

Claude Code **2.1.295 ou plus** requis (forme exec des hooks, `onFailure`). Version vérifiée : 2.1.296.

## Vue d'ensemble

plugin-plugin construit des plugins Claude Code au modèle de plugin-flutter. Il ne garde aucun état dans `~/.claude` ni dans sa propre racine installée : tout ce qu'il sait d'un plugin cible est dans le dépôt de ce plugin, sous `.plugin-plugin/`, et dans git.

Trois couches, chacune à sa place :

| Couche | Où | Rôle |
| --- | --- | --- |
| Jugement | `skills/` | Dialoguer avec Soon, poser une question à la fois, choisir l'étape suivante, présenter un résultat avec sa commande et son code de sortie |
| Déterministe | `scripts/pp.sh` et `scripts/lib/` | Tout ce qui doit toujours se produire de la même façon : charpente, contrôles, plans, journaux, gestes. Testé sans session |
| Garde | `hooks/` | Ce qui ne doit dépendre d'aucune consigne : un document approuvé modifié repasse en revue, un geste GitHub ne part qu'annoncé et accordé |

Aucun agent en v0.1 : chaque tâche est assez courte pour la session principale, et un agent ajouterait un transfert de contexte sans rien borner de plus qu'un script.

## Arborescence

```
plugin-plugin/
├── .claude-plugin/
│   ├── plugin.json          manifeste, sans e-mail
│   └── marketplace.json     marketplace locale, "source": "./"
├── skills/<skill>/SKILL.md  sept skills ; add/reference/ pour le détail par composant
├── hooks/
│   ├── hooks.json           quatre hooks en forme exec
│   └── scripts/             leurs scripts
├── scripts/
│   ├── pp.sh                l'outil en ligne de commande, point d'entrée unique
│   ├── lib/                 check.sh, consent.sh, doc-status.sh — partagés par pp.sh et les hooks
│   ├── scaffold/            la charpente d'un plugin créé : README, CHANGELOG, PROGRESS, docs/,
│   │                        .gitignore, garde de portée d'agent
│   └── facts/               base de faits, sondes, instantanés de formats
├── templates/               PRD.md et ARCHITECTURE.md d'un cadrage
├── evals/<skill>/<cas>/     suites d'évaluation des skills, écrites et vérifiées
├── tests/                   suite déterministe (voir « Tests »)
└── docs/                    PRD, PLAN, et les quatre documents d'usage
```

`scripts/` est la seule extension du modèle (décision a du plan) : un outil appelé par plusieurs skills et par les hooks.

## Composants

Coût en contexte permanent : **824 tokens** (seuil 1 000), mesuré par `claude plugin details` dans `tests/run-all.sh`.

### Skills

| Skill | Invocation | Appelle | User stories |
| --- | --- | --- | --- |
| `frame` | sur demande ou par le modèle | `pp.sh init-state`, `check-name`, `delegate`, `approve`, `status`, `checkpoint` | US-1 à US-4 |
| `create` | sur demande ou par le modèle | `pp.sh status`, `create`, `checkpoint` | US-5 à US-7 |
| `add` | sur demande ou par le modèle | `pp.sh check`, `check-name`, `out-of-scope`, `checkpoint` ; par composant (`reference/`) `check-skill`, `check-evals`, `eval-plan`, `eval-run`, `add-hook`, `add-agent`, `check-agent`, `add-mcp` | US-8 à US-17 |
| `check` | sur demande ou par le modèle | `pp.sh check` | US-18 |
| `resume` | sur demande ou par le modèle | `pp.sh resume` | US-34 |
| `release` | **seulement sur demande** (`disable-model-invocation`) | `pp.sh release`, `publish`, `mount` ; `release-write` (version du `plugin.json`, du CHANGELOG et du README, description de la marketplace locale) et `marketplace-entry` (entrée et ligne du README de la marketplace, ajoutées ou alignées par `--update`) sont des gestes du plan annoncé ; sans rien à publier, un alignement des descriptions seul (décision h) | US-20 à US-29, US-35 à US-37 |
| `reaudit` | **seulement sur demande** (`disable-model-invocation`) | `pp.sh reaudit`, `snapshot`, `diff-snapshots` | US-31 à US-33 |

`pp.sh rebuild` (US-19) n'a pas de skill : la reconstruction se lance à la main, comme le dit le README.

### Hooks

Les quatre sont présents dans **toutes** les sessions une fois le plugin installé pour le compte, et inertes hors de leur contexte.

| Hook | Événement, filtre | Mode | Actif seulement |
| --- | --- | --- | --- |
| `doc-status-guard` | PostToolUse, `Edit\|Write` | fail-open, `onFailure: continue` | sur un `docs/<NOM>.md` à côté d'un `.plugin-plugin/`, dont le statut dit APPROUVÉ |
| `checkpoint-reminder` | Stop | fail-open (exit 0 toujours) | avec un `.plugin-plugin/checkpoint.md` plus ancien que le dernier commit ou qu'un fichier modifié |
| `consent-capture` | UserPromptSubmit | fail-open, `onFailure: continue` | avec une annonce en attente dans `.plugin-plugin/pending` |
| `gesture-guard` | PreToolUse, `Bash\|Edit\|Write` | **fail-closed**, `onFailure: block` | dans un dépôt géré (un `.plugin-plugin/` à sa racine ou au-dessus) ou une copie de la marketplace `soon` |

`consent-capture` et `gesture-guard` ne se parlent pas : l'accord passe par le disque (`consents.log`), car les hooks d'un même événement tournent en parallèle, dans un ordre quelconque.

## L'outil `pp.sh`

Un seul script bash, appelé par les skills sous `${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh`, par les tests sous son chemin dans le dépôt. Chaque sous-commande :

- prend le dossier cible en argument, et n'écrit que là ;
- sort en 0 (fait), 1 (refusé, usage incorrect ou entrée illisible, avec la raison) ou 2 (un prérequis manque : `jq`, `claude`, `gh`, GitHub illisible) ;
- `check`, `resume` et la répétition `release` n'écrivent rien dans la cible, ce que les tests prouvent par une empreinte prise avant et après.

La charpente d'un plugin créé (`create`) et celle d'une reconstruction (`rebuild`) sortent de la même fonction, `scaffold` : un plugin reconstruit et un plugin neuf ont les mêmes manifestes, la même licence, le même harnais de tests.

## État de travail : `.plugin-plugin/`

Dans le dépôt du plugin cible, jamais ailleurs.

| Fichier | Écrit par | Versionné | Rôle |
| --- | --- | --- | --- |
| `approvals.log` | `pp.sh approve` | oui | accord de Soon sur un document, cité mot pour mot, avec l'empreinte du document approuvé |
| `decisions.md` | `pp.sh delegate` | oui | décisions déléguées pendant le cadrage, avec leur raison |
| `checkpoint.md` | `pp.sh checkpoint` | non | point de reprise : skill, branche, étapes faites et à faire, commandes et codes de sortie |
| `publication.json` | `pp.sh publish` | non | plan figé d'une publication, prouvé par la répétition |
| `pending` | `pp.sh publish`, `pp.sh mount` | non | l'étape annoncée, avec ses commandes exactes |
| `consents.log` | `consent-capture` seul | non | le « oui » tapé, pour une annonce donnée |
| `gestures.log` | `pp.sh publish` | non | chaque geste : fait, échoué, refusé, déjà fait, commande qui reprend |

Les journaux disent ce qui s'est passé ; ils ne décident de rien. Ce qui est fait se lit dans les dépôts (version et CHANGELOG à HEAD, étiquettes, dépôt GitHub, PR) : une reprise après une coupure ne refait rien.

## Les trois accords

| Accord | Annoncé par | Trace | Gardé par |
| --- | --- | --- | --- |
| Document de cadrage | le skill `frame`, en texte | `approvals.log` (citation et empreinte) | `doc-status-guard` : modifié, il repasse en REVUE ; `create` refuse un cadrage non approuvé |
| Lancement payant d'une évaluation | `pp.sh eval-plan` : sessions, coût estimé, plafond, compte | `--quote « oui »` passé à `pp.sh eval-run` | `eval-run` ne lance rien sans la citation |
| Geste GitHub | `pp.sh publish` / `mount` : l'étape et ses commandes | `consents.log`, écrit par `consent-capture` | `gesture-guard` : la commande annoncée passe une fois ; les gestes destructifs jamais |

## Base de faits et ré-audit

`scripts/facts/facts.json` : chaque fait sur la plateforme porte son énoncé, la version de Claude Code, la date, la source, la façon de le revérifier et son statut (confirmé, infirmé, à vérifier). Les sondes de `scripts/facts/probes/` revérifient par la validation stricte ; les instantanés de `scripts/facts/snapshots/` gardent la sortie de `claude plugin init` par version, lancée sous un HOME jetable. `reaudit` compare la version courante à celle des faits et liste ce qui est à revérifier ; la validation stricte l'emporte sur un fait qu'elle contredit.

## Tests

`bash tests/run-all.sh` : bash et jq, sans réseau, sans session, sans quota ; sort en 0, 1 ou 2.

| Dossier | Ce qu'il couvre |
| --- | --- |
| `tests/static/` | manifestes, en-têtes, chemins cités, faits, cadrage, reprise, `check`, évaluations, le harnais lui-même |
| `tests/hooks/` | chaque hook sur des entrées simulées |
| `tests/integration/` | les sous-commandes de bout en bout dans des dossiers jetables : création, ajouts, répétition et publication contre des dépôts nus et des doublures de `gh`, `claude` et `git push` ; `check`, reconstruction et réécriture sur les copies de lecture de `build/ref/` |
| `tests/project/` | le hook Stop de ce projet (`.claude/hooks/verify-tests.sh`) |
| `tests/rewrite/` | la réécriture de plugin-nixos, lancée par `test_rewrite_nixos` |

`tests/headers.sh` et `tests/mcp.sh` portent les règles d'en-tête et de serveur MCP en source unique : la suite de plugin-plugin s'en sert, et elles sont recopiées dans chaque plugin créé.

Chaque test prouve qu'il discrimine sur une copie faussée (`build/mutants/`), et le rouge puis le vert de chaque composant sont consignés dans PROGRESS.md.
