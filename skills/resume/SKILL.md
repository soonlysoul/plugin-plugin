---
name: resume
description: "Resume interrupted plugin-plugin work from disk — checkpoint, git, repository state — changing nothing before Soon agrees. Use when such work was cut off; not for new work nor a .forge/ project. « reprends où on s'est arrêté »."
argument-hint: "[dossier du plugin]"
when_to_use: "In a folder holding .plugin-plugin/."
---

# Resume the work

Address the user in French unless they write in another language.

The work resumes from disk, never from what an earlier session remembers. Until Soon agrees, this skill changes nothing: no edit, no commit, no checkout, no stash. Besides the tool, it runs one command: the targeted test of step 2.

## Step 1 — Read the state

Take the plugin folder from the arguments, or the current folder. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" resume <folder>` and keep its output: skill, steps done and left, last step with its command and exit code, targeted test, inconsistencies (newer commit, other branch, uncommitted files), blockers, a publication in progress. Exit 1: the folder is not a managed project; say so and stop.

## Step 2 — Confirm the real state

When the output names a `test ciblé`, run it from the plugin folder — `cd <folder> && <command>` — and nothing else: no other suite, no other step. A recorded `bash tests/run-all.sh` is the targeted test itself. A command that is not `bash tests/…`: show it and ask before running it. Report its exit code. Without a targeted test, say so and run nothing.

## Step 3 — Summary, then wait

Present at most ten lines: the skill, what is done, the confirmed state (command, exit code), the inconsistencies or « aucune », the blockers or « aucun », the next step. Never propose to redo a step marked done.

- `aucun point de reprise`: give the last commit, the branch and the uncommitted files, and ask which skill to run; never guess one.
- `reste : rien`: the skill is finished; give its next step.
- `publication en cours`: give the line. Its `reprise : …` command runs only on a literal « oui »; the publication's own announcements then take over, as `/plugin-plugin:release` describes.
- A blocker, another branch, newer commits, uncommitted files: name them, and let Soon decide before resuming. A checkout needs agreement; newer commits may already hold the next step; never stash.

Ask whether to resume from the next step, then stop and wait.

## Step 4 — After the agreement

Continue with the skill named in the checkpoint from its `étape suivante`, recording each further step with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" checkpoint <folder> done <n> --command "<command>" --exit <code>`. Skip that skill's `checkpoint … start`: it would wipe the steps done, and the tool refuses it.
