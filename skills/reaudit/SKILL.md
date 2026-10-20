---
name: reaudit
description: "Re-audit plugin-plugin's fact base: stale facts, changed formats, facts that strict validation contradicts. Use when Claude Code was updated; not for conformity checks or releases. « ré-audite la base de faits »."
argument-hint: "(aucun argument)"
when_to_use: "Explicitly, as /plugin-plugin:reaudit."
disable-model-invocation: true
---

# Re-audit the fact base

Address the user in French unless they write in another language.

The fact base and the format snapshots live in plugin-plugin itself. This skill reports; it edits nothing before Soon answers « oui ».

## Step 1 — Run the re-audit

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" reaudit` and show its output verbatim, with the exit code. When Soon gives a clone of plugin-plugin, or the session is in one (its `.claude-plugin/plugin.json` names `plugin-plugin`), audit the clone, where changes are made: add `--facts <clone>/scripts/facts/facts.json --snapshots <clone>/scripts/facts/snapshots --probes <clone>/scripts/facts/probes`. Never a folder under `~/.claude/plugins/`.

- Exit 2: the step is blocked. Name the missing prerequisite from the output, then stop.
- Exit 1: the step failed. Quote the error, then stop.
- The same command failing twice the same way: stop and expose the blocker; never retry a third time.

## Step 2 — Nothing to re-verify

When the output says `rien à revérifier depuis la version X` and `faits à corriger … : 0`, say exactly that, add the count of facts still `à vérifier`, and stop.

## Step 3 — Facts to re-verify

For each listed fact, show its `revérifier` command. Run only the checks that cost no quota and write nothing outside a throwaway directory: `--help`, `claude plugin validate`, `claude --plugin-dir … plugin details`, reading the official documentation (name the page and the sentence that decides).

List as not run, with the reason:

- a check that needs a Claude session (`claude -p`, `claude plugin eval`), with its estimated cost — 0.07 to 0.23 USD per session (facts `eval-session-cost-short-skill`, `eval-cost-per-session`). Launch one only after a literal « oui » to that question alone;
- a check that needs Soon at the keyboard, VSCode, or an install outside a throwaway directory.

Classify each fact checked against its statement: `confirmé`, it holds on the installed version; `infirmé`, it does not — a fact already `infirmé` stays so, with its version and date updated; `non tranché`, the check cannot decide — its status is kept. Give the command, its exit code and the line of output that decides.

## Step 4 — Formats changed

The re-audit diffs against a snapshot it then deletes. To show what changed, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" snapshot --out <throwaway directory>/<version>.json` — no quota, `plugin init` runs under a throwaway home — then, for each path listed, compare its old and new content: `jq -r --arg p '<path>' '.[$p] // ""'` on each snapshot, then `diff`. Name the rules of the model a change may break (manifest fields, hook form, agent header, skill header). `formats changés : bloqué`: no reference snapshot; say so, and propose storing one at step 6.

## Step 5 — Facts to correct

Strict validation wins over the fact base. For each fact listed under `faits à corriger`, state the validator's verdict, the fact as written, and the corrected statement and status proposed.

## Step 6 — Propose, then wait

Present the proposed changes to `scripts/facts/facts.json`, key by key: `status`, `claude_version`, `date`, `statement`, `note`, and each `probe.expect` set to the validator's current verdict. A disproved fact keeps its id, becomes `infirmé` and names its replacement in `note`; the corrected statement is a new fact, as `validate-root-marketplace-only` led to `validate-root-covers-plugin`. After a Claude Code update, add the command that stores the new snapshot: `bash scripts/pp.sh snapshot --out scripts/facts/snapshots/<version>.json`. These changes are made only in a clone of the plugin-plugin repository, never in the installed plugin, whose directory changes at every update.

Ask whether to apply them — a question of its own, apart from any paid check — then stop and wait. Only a literal « oui » counts as agreement.

## Step 7 — After the « oui »

In the clone: edit `scripts/facts/facts.json`, store the snapshot, run the re-audit again against the clone until `faits à corriger … : 0`, then `bash tests/run-all.sh`. Report each command with its exit code. Propose the commit; never make it unasked.
