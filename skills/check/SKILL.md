---
name: check
description: "List the gaps of a plugin to the model — manifests, root files, tree, hook form, components, harness, stray files, credentials in clear — changing nothing. Use when Soon asks whether a plugin follows the model; not for fixing one. « plugin-nixos suit-il le modèle ? »."
argument-hint: "[dossier du plugin]"
when_to_use: "On any Claude Code plugin folder, before adding to it or rebuilding it."
---

# Check a plugin against the model

Address the user in French unless they write in another language.

This skill only reads: no edit, no commit, no checkpoint.

## Step 1 — Run the check

Take the plugin folder from the arguments, or the current folder. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" check <folder>`.

- Exit 0, « écarts : 0 »: the plugin follows the model.
- Exit 1, « écarts : N »: the gaps follow, one per line.
- Exit 1, « refusé »: the folder is not a plugin; say so and stop.
- Exit 2: a prerequisite is missing; name it and stop.

## Step 2 — Report

Relay every gap, grouped by its category in brackets, with the file and the line it names. A credential is never copied: the tool gives its line only, and so do you. End with one line:

- no gap: plugin-plugin can add to it (`/plugin-plugin:add`) without touching its content;
- gaps: plugin-plugin adds nothing to it as it is — its suite would not cover what it adds. Bringing it to the model is a rewrite that Soon decides.

Propose no fix and change nothing: a gap is reported, not acted on.
