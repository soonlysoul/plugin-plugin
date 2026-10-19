---
name: create
description: "Create a dedicated plugin from an approved framing: name checked on GitHub, model skeleton, git, its own suite run green. Use when the framing is approved; not for adding components. « crée le plugin »."
argument-hint: "[dossier cible]"
when_to_use: "After /plugin-plugin:frame."
---

# Create a plugin

Address the user in French unless they write in another language.

The creation writes only in the target folder, and only when that folder holds nothing but an approved framing. It never touches GitHub beyond reading it.

## Step 1 — Check the framing

Take the target folder from the arguments, or ask for it. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" status <folder>/docs/PRD.md`, then the same for `docs/ARCHITECTURE.md`. Unless both say `APPROUVÉ`, stop: give the status read, and point to `/plugin-plugin:frame <folder>`.

## Step 2 — Name and description

Read the name in the PRD (« Décisions d'implémentation ») and write a one-sentence English description from its « Solution ». Show both, then go on: they come from an approved document.

## Step 3 — Create

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" create <folder> --name <name> --description "<description>"`, and show its output verbatim with the exit code.

- Exit 1 with `refusé` — a name out of the rule, a name already in the marketplace `soon` or on GitHub, a file outside the framing, a framing not approved. Quote the reason; the folder is left as it was. Stop.
- Exit 2 — blocked: `gh` missing or GitHub unreadable. Name the cause, then stop.
- Exit 1 after `suite du plugin créé : exit …` — the skeleton exists but its suite is red. Show the failing lines and stop: never fix a created file by hand, the fix belongs in plugin-plugin.
- The same command failing twice the same way: stop and expose the blocker.

## Step 4 — Report, then propose the first commit

Report the plugin created, its suite result (`réussies`, `échouées`, `sautées`, `bloquées`) and the strict validation. Then propose, with the exact commands, a first local commit:

`git -C <folder> add -A` then `git -C <folder> commit -m "chore: charpente de <name>"`

Run them only on a literal "oui". Nothing goes to GitHub here: the repository is created by the release, later.

## Step 5 — Next step

Give the next step, `/plugin-plugin:add`, to add the first component. Stop there.
