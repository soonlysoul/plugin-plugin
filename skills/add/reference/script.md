# Adding a script

Steps for the checkpoint: `Script et appelant|Squelette|Rouge|Code|Vert|Clôture`.

A script of `scripts/` is a tool that a component runs: a skill or an agent by `bash` and its path under the plugin root variable, `CLAUDE_PLUGIN_ROOT`, followed by `/scripts/<name>.sh`; a hook from its own script; an MCP declaration as its launcher. It is built and tested before that caller cites it.

## 1. The script and its caller

Ask, one question at a time: what it does — deterministic work; what needs judgment is a skill —; its subcommands, what each reads and writes, and its exit codes (0 done, 1 refused or failed, 2 a prerequisite missing); the commands it runs that reach the network or the machine (`gh`, `git`, `curl`…), which its test replaces by doubles; and the component that will call it: `skills/<skill>/SKILL.md`, `agents/<agent>.md`, `hooks/scripts/<hook>.sh` or `.mcp.json`. That component may not exist yet.

## 2. Skeleton

Run `bash <pp> add-script <folder> --name <name> --caller <file>`. A refusal names the broken rule — name outside kebab-case, a caller outside those four forms, the script or its test already there —: relay it, fix it with the user, and run again. It writes `scripts/<name>.sh` and its test, `tests/static/test_script_<name>.sh` with each `-` of the name turned to `_` (the paths its `écrit :` line gives), and nothing else. A line `avertissement :` means the plugin's copy of `tests/static/test_paths.sh` predates the `# CALLER:` mark: relay it — that suite stays red until the caller cites the script; bringing the current `test_paths.sh` into that plugin is Soon's call, outside this addition.

The skeleton refuses every call by its usage, exit 1, under the mark `# CALLER: <file>`: until that component cites the script, the plugin's `test_paths` skips it as under construction instead of failing, and `/plugin-plugin:release` refuses to publish it. Its test runs it with `bash`, as its callers do: its contract — an unknown call refused, exit 1, the reason on stderr — passes already, and `case_placeholder` fails.

## 3. Red

In the test, replace the `case_placeholder` call by the script's cases: for each subcommand, `run_script <arguments>` and what it must give — `STATUS`, `STDOUT`, `STDERR`, the files it writes under a `mktemp -d` folder —; a refusal for each bad input; a missing prerequisite, exit 2. A command it runs is replaced by a double: a script of the same name in a temporary folder, put first through `SCRIPT_ENV=(PATH="<folder>:$PATH")`, or an environment variable the script reads in its place. A script that takes no subcommand, such as the launcher of an MCP server, replaces the contract's case by its own refusal. Run it, `bash <that path>`: each case must fail on the skeleton's refusal — `exit 1`, its usage on stderr —, not on an error of the test. Record the output and the exit code.

## 4. The code

Write the header — what the script does, its subcommands, its exit codes —, then one branch of the `case` per subcommand, its work in a function above. Quote every variable; give the reason of a refusal on stderr through `die`; check a prerequisite with `need`, exit 2; no absolute path, an interpreter's included; nothing installed. Keep the `# CALLER:` mark while the caller does not cite the script.

## 5. Green

Run the test again, then `bash tests/run-all.sh`: `test_paths` shows the script `sauté`, under construction, until its caller cites it, and `shellcheck` checks it. Record both outputs, red then green, in the plugin's `PROGRESS.md`. The caller comes next — added by this skill when it is a new skill, agent, hook or MCP declaration —: once it cites the script, the mark no longer counts; remove it then.
