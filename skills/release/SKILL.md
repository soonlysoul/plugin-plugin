---
name: release
description: "Rehearse the release of a plugin of the model — checks, version, CHANGELOG, tag, context cost, each gesture with its command — sending nothing. Use when Soon asks for a release; not for creating a plugin. « répète la publication »."
argument-hint: "[dossier du plugin] [--bump patch|minor|major]"
when_to_use: "Explicitly, as /plugin-plugin:release."
disable-model-invocation: true
---

# Rehearse a release

Address the user in French unless they write in another language.

This version only rehearses. It reads GitHub and never writes to it, and it leaves the plugin's folder as it was. No listed gesture is run, not even on a "oui": the publication itself is not available yet.

## Step 1 — The plugin

Take the folder from the arguments, or ask for it. It must be the root of the plugin's own git repository, on `main`, every change committed.

## Step 2 — Rehearse

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" release <folder>` and show its output verbatim, with the exit code.

- Exit 1 with `refusé` — uncommitted changes, a red strict validation or suite, another branch, a folder inside another repository, an `origin` elsewhere, nothing since the last tag, a tag the check refuses. Quote the reason and stop: the fix goes into the plugin and a commit, then a new rehearsal.
- Exit 2 — blocked: `gh` or `claude` missing, GitHub unreadable. Name the cause, then stop.
- The same command failing twice the same way: stop and expose the blocker.

## Step 3 — The nature of the change

The tool reads the nature of the change from the components: one removed is major, one added is minor, anything else a patch. Read the commits since the last tag (`git -C <folder> log --oneline <tag>..HEAD`). When a change inside a component breaks what used it — an argument renamed, a behaviour removed — say so, and propose `--bump major` (or `--bump minor`) with the reason. Re-run with it only after a literal "oui". The tool refuses a bump lower than the nature of the change.

## Step 4 — Report

Present, from the output:

- the version, and why;
- the CHANGELOG entry drafted;
- the context cost of each component, and the alert above 1 000 tokens if there is one;
- the gestures in order, each with its exact command, those marked `[GitHub]` going out of the machine;
- the commands Soon runs on each device: after the merge of the PR for a new plugin, after the push for an update.

End with « Répétition : rien n'a été envoyé. » and stop.
