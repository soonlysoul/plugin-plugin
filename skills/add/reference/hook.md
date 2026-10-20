# Adding a hook

Steps for the checkpoint: `Règle et contexte|Avertissement|Squelette|Rouge|Règle|Vert|Clôture`.

## 1. The rule and its context

Ask, one question at a time: what the hook enforces — a deterministic check; one that needs judgment is a skill, not a hook —; the event and, for a tool event, the exact tools it watches (`Bash|Monitor`, `Edit|Write`); the mode; the context outside of which it stays silent (a file type, a folder such as `.plugin-plugin/`, an agent).

- **fail-closed**: blocks on any doubt — exit 2 on an internal error, `onFailure: block`. Only `PreToolUse` and `UserPromptSubmit` can block.
- **fail-open**: never in the way — exit 0 on any problem, `onFailure: continue`; `Stop` takes no `onFailure`.

## 2. Warn before writing

Run `bash <pp> add-hook <folder> --name <name> --event <event> [--matcher <tools>] --mode <mode> --dry-run`. Show its first line, the scope warning — installed for the account, the hook runs in every session, in every project — and the files it would write. Ask whether to write it, and stop. Only a literal "oui" goes on.

## 3. Skeleton

Run the same command without `--dry-run`. It writes `hooks/scripts/<name>.sh`, whose input contract is done and whose rule is not; its test, `tests/hooks/test_<name>.sh` with each `-` of the name turned to `_` (the path its `écrit :` line gives); the exec-form entry of `hooks/hooks.json`; and the hook's line in `docs/INSTALLATION.md`, under « Portée des hooks ».

## 4. Red

In that test, replace the `rule_placeholder` call by the rule's simulated inputs, built with `jq -nc`: what it blocks (`expect_blocked`) or reports, what it lets through (`expect_silent_allow`), and an input outside its context, where it stays silent. Run it, `bash <that path>`: the rule's cases must fail — the skeleton lets everything through — and the contract's cases must pass. Record the output and the exit code.

## 5. The rule

Replace `# RULE: the rule is not written yet.` by the rule, and the `TODO` header line by what it checks. Quote every variable; give the reason on stderr; exit 2 to block; no absolute path; nothing that depends on another hook having run first — the hooks of an event run in parallel, in any order.

## 6. Green

Run the test again, then `bash tests/run-all.sh`: the hook's wiring, its exec form, its mode against its `onFailure`, `shellcheck`. Record both outputs, red then green, in the plugin's `PROGRESS.md`.
