# Adding an agent

Steps for the checkpoint: `Tâche et outils|Rouge|Agent|Description et corps|Vert|Clôture`.

## 1. The task and the tools

Ask, one question at a time: the one bounded task the agent does for the main session, and what it reports; the tools it needs, one by one, from `Read`, `Grep`, `Glob`, `Bash`, `Write`, `Edit`, `NotebookEdit`, `WebFetch`, `WebSearch`, `TodoWrite`, `Skill`, `Monitor` — never `Agent`; the model (`sonnet`, `opus`, `haiku`, `fable`, `inherit`); for a writing agent, the folders it writes in; for an agent with `Bash`, the exact commands it may run. A reviewer — a name holding `review` — never gets `Write` nor `Edit`.

## 2. Red

Run `bash <pp> add-agent <folder> --name <name> --tools "<tools>" --model <model> [--writes "<folders>"] [--bash "<commands>"] --test-only`. It writes `tests/static/test_agent_<name>.sh` alone. Run it: it must fail on « agents/<name>.md présent ». Record the output and the exit code.

## 3. The agent

Run the same command without `--test-only`. It writes `agents/<name>.md` — header with the tools and the model, the fixed report `STATUS` / `FILES_CHANGED` / `COMMANDS_RUN` / `OPEN_QUESTIONS` — and, for an agent that writes or runs Bash, its scope in `hooks/agent-scope.json`. The first such agent also brings the `agent-scope-guard` hook (PreToolUse, fail-closed), its test, and its line in `docs/INSTALLATION.md`: show the scope warning it prints first.

## 4. Description and body

Replace the `TODO`s: a description « Use this agent when …; not for … » of 200 to 1 000 characters; the responsibilities, the approach in steps, the output format. Run `bash <pp> check-agent <folder>/agents/<name>.md` until it says `conforme`.

## 5. Green

Run the agent's test, then `bash tests/run-all.sh`: header, tools, model, scope, the guard's simulated inputs for every agent of the plugin. Record both outputs, red then green, in the plugin's `PROGRESS.md`.
