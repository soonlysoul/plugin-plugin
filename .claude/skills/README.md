# Skills de ce projet

Un skill par répertoire, décrit par un `SKILL.md` à frontmatter YAML. Claude Code
les découvre tout seuls, sans réglage, dès qu'une session travaille sur des
fichiers de ce projet.

```
.claude/skills/
└── nom-du-skill/
    ├── SKILL.md          obligatoire
    └── references/       optionnel — lu à la demande, pas au démarrage
```

## Le frontmatter

```markdown
---
name: nom-du-skill
description: Ce que fait ce skill, ET quand l'invoquer. Une phrase, à la troisième personne.
---

La procédure, en étapes numérotées.
```

`description` est le seul champ que Claude lit **en permanence** : c'est lui qui
décide si le skill est invoqué. Une description qui dit seulement *ce que fait*
le skill sans dire *quand* s'en servir ne sera jamais déclenchée au bon moment.
Écrire les deux.

## Ce qu'un skill n'est pas

| Artefact | Rôle | Ne fait pas |
|---|---|---|
| **Skill** | décrit une procédure | ne décide pas |
| Agent (`.claude/agents/`) | réalise une analyse spécialisée | n'impose rien |
| Hook (`.claude/hooks/`) | impose un contrôle systématique | n'analyse pas |
| Permission (`settings.json`) | décide si une action est autorisée | n'explique pas |
| MCP (`.mcp.json`) | donne accès à un système externe | n'autorise pas |

Mettre une décision dans un skill, ou une analyse dans un hook, produit un
système dont plus personne ne sait où il refuse.

## Portée

Contrairement à `.claude/settings.json`, les skills **remontent** l'arborescence :
un skill posé dans un répertoire parent est visible depuis les sous-projets.
Vérifié le 2026-08-17 — les skills d'un projet sont annoncés avec la mention
« applies when working on files under &lt;racine&gt; ».

## Exemples sur cette machine

- `~/Documents/project-code/Orchestrator/.claude/skills/` — six skills de cadrage
  (`cadre`, `planifie`, `investigue`, `design`, `illustre`, `interroge`)
- `~/Documents/code/.claude/skills/` — douze skills de cycle de vie projet
  (`brief-client`, `choose-stack`, `implement-feature`, `review-code`, …)

Ce répertoire est vide à dessein : un skill générique qu'aucun projet n'invoque
coûte du contexte à chaque session sans jamais servir.
