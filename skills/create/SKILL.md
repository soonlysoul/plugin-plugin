---
name: create
description: "Create a dedicated plugin from an approved framing: name checked on GitHub, model skeleton, git, its own suite run green. Use when the framing is approved; not for framing or adding components. « crée le plugin »."
argument-hint: "[dossier cible]"
when_to_use: "After /plugin-plugin:frame."
---

# Create a plugin

Address the user in French unless they write in another language.

The creation writes only in the target folder, and only when that folder holds nothing but an approved framing. It never touches GitHub beyond reading it.

**Checkpoint.** Once step 1 has passed, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" checkpoint <folder> start --skill create --steps "Vérifier le cadrage|Nom et description|Créer|Rapport et premier commit|Étape suivante"`, then record step 1. After each step: `… checkpoint <folder> done <n> --command "<command>" --exit <code>`, with `--test "bash tests/run-all.sh"` after step 3; on a blocker: `… checkpoint <folder> block "<reason>"`. A refused `start` means a creation was interrupted here: resume it from its next step.

## Step 1 — Check the framing

Take the target folder from the arguments, or ask for it. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" status <folder>/docs/PRD.md`, then the same for `docs/ARCHITECTURE.md`. Unless both say `APPROUVÉ`, stop: give the status read, and point to `/plugin-plugin:frame <folder>`. A missing document, or a folder without `.plugin-plugin/`, was never framed: point to the same; never run `init-state` here.

## Step 2 — Name and description

Read the name in the PRD (« Décisions d'implémentation ») and write a one-sentence English description from its « Solution ». Show both, then go on: the name comes from an approved document; the description is yours, and Soon may amend it before step 3.

## Step 3 — Create

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" create <folder> --name <name> --description '<description>'` — single quotes, each `'` written `'\''` — and show its output verbatim with the exit code.

- Exit 1 with `refusé` — a name out of the rule, a name already in the marketplace `soon` or on GitHub, a file outside the framing, a framing not approved. Quote the reason; the folder is left as it was. Stop.
- Exit 2 — blocked: `jq` or `gh` missing, or GitHub unreadable. Name the cause, then stop.
- Exit 1 with `usage` or `échec` — quote it and stop. `échec : git init` comes after the skeleton is written.
- Exit 1 after `suite du plugin créé : exit 1` — the suite is red: show the lines under `échouées`. After `exit 2` — it is blocked: name the prerequisite from the lines under `bloquées`. Stop either way: never fix a created file by hand, the fix belongs in plugin-plugin.
- Once the skeleton is written, the folder no longer holds a bare framing, and a new `create` refuses it: say so; the way back is Soon's to decide.
- The same command failing twice the same way: stop and expose the blocker.

## Step 4 — Report, then propose the first commit

Report the plugin created and its suite: `réussies`, `échouées`, `sautées`, `bloquées`, `alertes`, with their `  - ` lines. The strict validation passed when no `claude plugin validate` line stands under `échouées` or `bloquées`; under `sautées`, a component folder still absent (`skills`, `agents`) is expected. Then propose, with the exact commands, a first local commit:

`git -C <folder> add -A` then `git -C <folder> commit -m "chore: charpente de <name>"`

Run them only on a literal « oui ». Nothing goes to GitHub here: the repository is created by the release, later.

## Step 5 — Next step

Give the next step, `/plugin-plugin:add <folder>`, to add the first component. Stop there.
