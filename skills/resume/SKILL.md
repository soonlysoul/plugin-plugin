---
name: resume
description: "Resume interrupted plugin work from disk — checkpoint, git, repository state — in ten lines, changing nothing before Soon agrees. Use to resume or see where work stopped; not for new work. « reprends où on s'est arrêté »."
argument-hint: "[dossier du plugin]"
when_to_use: "In a folder holding .plugin-plugin/."
---

# Resume the work

Address the user in French unless they write in another language.

The work resumes from disk, never from what an earlier session remembers. Until Soon agrees, this skill is read-only: no edit, no commit, no checkout, no stash.

## Step 1 — Read the state

Take the plugin folder from the arguments, or the current folder. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" resume <folder>` and keep its output: skill, steps done and left, last step with its command and exit code, targeted test, inconsistencies (newer commit, other branch, uncommitted files), blockers. Exit 1: the folder is not a managed project; say so and stop.

## Step 2 — Confirm the real state

When the output names a `test ciblé`, run that command alone, and nothing else: no full suite, no other step. Report its exit code. Without a targeted test, say so and run nothing.

## Step 3 — Summary, then wait

Present at most ten lines: the skill, what is done, the confirmed state (command, exit code), the inconsistencies or « aucune », the next step. Never propose to redo a step marked done. Ask whether to resume from the next step, then stop and wait.

## Step 4 — After the agreement

Continue with the skill named in the checkpoint, from its next step, recording each step as that skill says.
