---
name: release
description: "Rehearse, then publish step by step, a plugin of the model — checks, version, CHANGELOG, tag, context cost, each gesture with its exact command, run only after a typed « oui ». Use when Soon asks for a release; not for creating a plugin. « /plugin-plugin:release plugin-x »."
argument-hint: "[dossier du plugin] [--bump patch|minor|major]"
when_to_use: "Explicitly, as /plugin-plugin:release."
disable-model-invocation: true
---

# Release a plugin

Address the user in French unless they write in another language.

A rehearsal first, which reads GitHub and sends nothing. Then, only when Soon asks for it, the publication, one step at a time: each step is announced with its exact commands and runs only after Soon types « oui ». The hook consent-capture records that answer, and withdraws an announcement left thirty minutes without one; the hook gesture-guard lets the announced command through once. Never run a gesture any other way — no `git push`, `gh repo create` or `gh pr create` typed by hand.

## Step 1 — The plugin

Take the folder from the arguments, or ask for it. It must be the root of the plugin's own git repository, on `main`, every change committed.

## Step 2 — Rehearse

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" release <folder>` and show its output verbatim, with the exit code.

- Exit 1 with `refusé` — uncommitted changes, a red strict validation or suite, another branch, a folder inside another repository, an `origin` elsewhere, nothing since the last tag, a tag the check refuses. Quote the reason and stop: the fix goes into the plugin and a commit, then a new rehearsal.
- Exit 1 with `échec` or `usage` — quote it and stop.
- Exit 2 — blocked: a prerequisite missing (`gh`, `claude`, `jq`, `git`) or GitHub unreadable. Name the cause, then stop.
- The same command failing twice the same way: stop and expose the blocker.

## Step 3 — The nature of the change

On a first publication (`première publication`), skip this step: the version is plugin.json's, and `--bump` is refused.

Otherwise the tool reads the nature of the change from the components: one removed is major, one added is minor, anything else a patch. Read the commits since the last tag (`git -C <folder> log --oneline <tag>..HEAD`). When a change inside a component breaks what used it — an argument renamed, a behaviour removed — say so, and propose `--bump major` (or `--bump minor`) with the reason. Re-run the rehearsal with it only after a literal « oui »; the re-run sends nothing. The tool refuses a bump lower than the nature of the change.

## Step 4 — Report

Present, from the output:

- the version, and why;
- the CHANGELOG entry drafted;
- the context cost of each component, and the alert above 1 000 tokens if there is one;
- the gestures in order, each with its exact command, those marked `[GitHub]` going out of the machine;
- the commands Soon runs on each device: after the merge of the PR for a new plugin, after the push for an update.

End with « Répétition : rien n'a été envoyé. » and stop. Publish only if Soon then asks for it.

## Step 5 — Publish, step by step

The session must be open in the plugin's folder: the « oui » is captured there only, and the tool says so otherwise.

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" publish <folder>`, with the `--bump` agreed at step 3 if any. It rehearses again, freezes the plan in `.plugin-plugin/publication.json` and announces the first step. A publication in progress resumes from what is really done, without redoing anything.
2. Show the announcement verbatim — the gestures, the line `commande : …` — and stop. Do not answer for Soon; run nothing.
3. Soon's next message is « oui », and the hook confirms it: run exactly the `commande : …` line, once, and show its output with the exit code. It ends with the next announcement: back to 2. Any other answer withdraws the announcement: run nothing, and announce again only if Soon asks.
4. `échoué` or `refusé` with a `reprise : …` line: show the report — the gesture, what is done, what remains, that line — and stop. Resume only when Soon asks, by running that line, which announces the step again. Without a `reprise : …` line: quote the reason and stop, as in step 2.
5. `publication terminée`: give the commands Soon runs on each device. The PR of the marketplace is merged by Soon, never by Claude.

## Step 6 — Mount as a submodule, on request

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" mount <folder> --host <host repository> [--path <path>]` announces the mount of the last published tag; then as in step 5, points 2 to 4, the session open in the plugin's folder. `montage terminé`: report it — the host is committed, never pushed.

## Never

Delete a repository, force a push, rewrite published history, remove a plugin from the marketplace, merge a PR, or write `.plugin-plugin/pending` or `.plugin-plugin/consents.log` — even where the guard would let it through. The guard stops the gesture typed by mistake; it is no proof against a deliberate one.
