# Installation — plugin-plugin

## Prérequis

| Outil | Version | Pourquoi |
| --- | --- | --- |
| Claude Code | **2.1.295 ou plus** | Les hooks sont en forme exec et déclarent `onFailure` |
| `bash` | 5.x vérifié | Hooks et `scripts/pp.sh` sont lancés par `bash`, trouvé sur le `PATH` ; jamais `/bin/bash`, absent sous NixOS |
| `git` | 2.x | Création, reprise, publication |
| `jq` | toute version récente | `pp.sh` et les hooks lisent et écrivent du JSON. Sans lui, `pp.sh` sort en 2 ; `gesture-guard`, fail-closed, bloque un geste dans un dépôt géré, et reste inerte ailleurs |
| `gh` | authentifié | Vérifier qu'un nom est libre, lire la marketplace `soon`, publier. Sans lui, ces étapes sont « bloquées », jamais réussies |

Vérifier : `claude --version`, `git --version`, `jq --version`, `gh auth status`.

## Essayer sans installer

Depuis la racine d'un clone :

```bash
claude --plugin-dir .
```

Le plugin vaut pour cette session seule, sous le nom `plugin-plugin@inline`, et prend le pas sur une copie installée. Après une modification de ses fichiers : `/reload-plugins`.

## Installer depuis la marketplace `soon`

À partir de la 0.1.1, première version publiée. Aucun compte GitHub n'est nécessaire.

```bash
claude plugin marketplace add soonlysoul/claude-plugins
claude plugin install plugin-plugin@soon --scope user
```

Mettre à jour : `claude plugin marketplace update soon`, puis `claude plugin update plugin-plugin@soon`. Un appareil ne reçoit une nouvelle copie que si la `version` du plugin a changé.

## Installer depuis la marketplace locale (développement)

Le dossier du plugin est aussi une marketplace, nommée `plugin-plugin`. C'est ainsi qu'il a été chargé pour construire le témoin de la phase 15 :

```bash
claude plugin marketplace add ./ --scope local
claude plugin install plugin-plugin@plugin-plugin --scope local
```

L'installation copie **tout** le dossier dans `~/.claude/plugins/cache/`, fichiers ignorés par git compris : `build/` y passe (136 Mo mesurés le 2026-10-20). N'ajoutez pas les deux marketplaces, `soon` et `plugin-plugin`, sur la même machine : le plugin y serait installé deux fois, avec ses hooks en double.

## Portée des hooks

Installé pour le compte, plugin-plugin pose ses quatre hooks dans **toutes** les sessions de la machine. Chacun reste inerte hors de son contexte :

| Hook | Agit seulement |
| --- | --- |
| `doc-status-guard` | sur un document de cadrage approuvé, dans un dossier qui porte `.plugin-plugin/` |
| `checkpoint-reminder` | avec un point de reprise `.plugin-plugin/checkpoint.md` périmé |
| `consent-capture` | avec une étape de publication annoncée et en attente de réponse |
| `gesture-guard` | sur un geste GitHub, dans un dépôt de plugin géré ou une copie de la marketplace `soon` |

Ailleurs, aucun ne parle ni ne bloque. Le détail : [SECURITY](SECURITY.md).

## Vérifier l'installation

```bash
claude plugin details plugin-plugin
```

Attendu : 7 skills, des hooks sur `PreToolUse`, `PostToolUse`, `UserPromptSubmit` et `Stop`, environ 820 tokens ajoutés à chaque session.

Depuis un clone, la suite déterministe :

```bash
bash tests/run-all.sh
```

## Désinstaller

```bash
claude plugin uninstall plugin-plugin@soon --scope user
```

Les plugins créés gardent leur dossier `.plugin-plugin/` (accords, décisions, point de reprise) : ils vous appartiennent.
