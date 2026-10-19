# Adding a skill

Steps for the checkpoint: `Demandes|Suite d'évaluation|Rouge|Skill|Vert|Clôture`.

## 1. Collect the requests

Ask, one question at a time: what the skill does, in one sentence; two to four requests that must trigger it, phrased as Soon would type them, never naming the skill; one or two that must not; whether the skill needs Bash. A skill that needs Bash is evaluated in Claude Code's sandbox, which needs bubblewrap and socat: without them its cases are « bloqué : bwrap absent », never « réussi ».

## 2. Write the suite

One case per request: `evals/<skill>/<skill>-<case>/case.yaml`, written in JSON (JSON is YAML, and the suite is then checked with no other dependency):

- `schema_version` `"1.0"`, `name` `<skill>-<case>`, `runs` `3`, `execution.prompt` the request verbatim, `execution.allowed_tools` the read-only tools it needs (`Skill`, `Read`, `Glob`, `Grep`), plus `Bash` only when the skill needs it.
- A case that must trigger: a `tool_used` grader on `Skill`, with `input_match` `"\"skill\"\\s*:\\s*\"(?:[\\w-]+:)?<skill>\""`; and a grader on the result — `regex` on `last_message`, `file_exists`, or `llm` with concrete PASS and FAIL conditions.
- A case that must not trigger: the same `tool_used` grader with `min: 0`, `max: 0`, `arm: both`; and a grader on the result.
- A result that only the skill can give: a case the model already passes without the plugin proves nothing.

Run `bash <pp> check-evals <folder> <skill>`. Each refusal names the rule to fix.

## 3. Red, before the skill exists

Run `bash <pp> eval-plan <folder> <skill> --one-arm` and show the announcement verbatim: sessions, estimated cost, cap, paying account, exact command. Ask for agreement, and stop. Only a literal "oui" counts: then run `bash <pp> eval-run <folder> <skill> --one-arm --quote "<Soon's message, verbatim>"`. A different cap (`--max-cost <usd>`) is set before the announcement, never after.

A plugin folder never trusted is refused outside a terminal: `eval-run` then says « bloqué » and gives the free command Soon runs once in a terminal to trust it. Never pass `--trust-plugin`.

Expected: `verdict : rouge`, the cases that must trigger failing. A case already green there tests nothing the skill brings: rewrite it, check again.

## 4. Write the skill

Write `skills/<skill>/SKILL.md`: header `name`, `description` (« <what it does>. Use when …; not for … » with one or two trigger phrases quoted in French), `argument-hint`, `when_to_use`; never `allowed-tools`. Body in the imperative, under 500 lines, details in `reference/`. Run `bash <pp> check-skill <folder>/skills/<skill>/SKILL.md` until it says `conforme`.

## 5. Green, with the baseline

Announce again, without `--one-arm`: the baseline arm, without the plugin, is what proves the skill brings something. On a literal "oui", run `eval-run` the same way. Expected: `verdict : vert`, every case at 1.00, and a positive Δ on each case that must trigger. A case refused with `le témoin réussit` is rewritten, never kept.

## 6. Record

In the plugin's `PROGRESS.md`: both commands, their exit codes, and the verdict lines of each pass, red then green, with the cost reported.
