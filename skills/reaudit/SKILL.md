---
name: reaudit
description: "Re-audit plugin-plugin's fact base: stale facts, changed formats, facts strict validation contradicts. Use when Claude Code was updated; not for conformity checks or releases. « ré-audite la base de faits »."
argument-hint: "(aucun argument)"
when_to_use: "Explicitly, as /plugin-plugin:reaudit."
disable-model-invocation: true
---

# Re-audit the fact base

Address the user in French unless they write in another language.

The fact base and the format snapshots live in plugin-plugin itself. This skill reports; it edits nothing before the user answers "oui".

## Step 1 — Run the re-audit

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" reaudit` and show its output verbatim, with the exit code.

- Exit 2: the step is blocked. Name the missing prerequisite from the output, then stop.
- Exit 1: the step failed. Quote the error, then stop.
- The same command failing twice the same way: stop and expose the blocker; never retry a third time.

## Step 2 — Nothing to re-verify

When the output says `rien à revérifier depuis la version X` and `faits à corriger … : 0`, say exactly that, add the count of facts still `à vérifier`, and stop.

## Step 3 — Facts to re-verify

For each listed fact, show its `revérifier` command. Run only the checks that cost no quota and write nothing outside a throwaway directory: `--help`, `claude plugin validate`, `claude --plugin-dir … plugin details`, reading the official documentation. A check that needs a Claude session (`claude -p`, `claude plugin eval`) is listed as not run, with its estimated cost; never launch it without a literal "oui".

Classify each fact checked: `confirmé` or `infirmé`, with the command, its exit code and the line of output that decides.

## Step 4 — Formats changed

For each format listed as changed, show what changed with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" diff-snapshots <old> <new>` when both snapshots are on disk, and name the rules of the model it may break (manifest fields, hook form, agent header, skill header).

## Step 5 — Facts to correct

Strict validation wins over the fact base. For each fact listed under `faits à corriger`, state the validator's verdict, the fact as written, and the corrected statement and status you propose.

## Step 6 — Propose, then wait

Present the proposed changes to `scripts/facts/facts.json` (status, version, date, statement) and, after a Claude Code update, the command that stores the new snapshot: `bash scripts/pp.sh snapshot --out scripts/facts/snapshots/<version>.json`. These changes are made only in a clone of the plugin-plugin repository, never in the installed plugin, whose directory changes at every update.

Ask whether to apply them, then stop and wait. Only a literal "oui" counts as agreement.
