# Declaring an MCP server

Steps for the checkpoint: `Serveur et valeurs|Rouge|Déclaration|Vert|Clôture`.

The server already exists: this procedure declares it, it never writes its code nor installs it.

## 1. The server and its values

Ask, one question at a time: the server's name, in kebab-case; local or remote.

- **Local**: the launcher, a bash script of the plugin, `scripts/<name>.sh`, that the declaration runs with `bash` from the plugin's root. It starts a server already on the machine, and says on stderr what is missing when it is not there; it never installs anything (`npm install`, `npx`, `pip install`, `uvx`…). If the launcher does not exist yet, write it first, with `#!/usr/bin/env bash`. Then its arguments, and the names of the variables it reads from the user's environment.
- **Remote**: its address, in HTTPS or WSS only; the headers it needs, each secret one as `${VAR}`.

A value the user keeps to themselves — a token, a key, a path of their own — is never written: it is named, `${NAME}`, and the user sets it in their environment.

## 2. Red

Run `bash <pp> add-mcp <folder> --name <name> (--launcher scripts/<name>.sh [--args "<a>,<b>"] [--env "<VAR>,<VAR>"] | --url <address> [--header '<Name>=<value>']…) --test-only`. A refusal names the broken rule — address in HTTP, launcher absent or outside `scripts/`, an imperative install, a secret in clear, a variable outside `${VAR}` —: relay it, fix it with the user, and run again. Otherwise it writes the server's test alone, `tests/static/test_mcp_<name>.sh` with each `-` of the name turned to `_`: run the path its `écrit :` line gives. It must fail on « serveur <name> déclaré ». Record the output and the exit code.

## 3. The declaration

Run the same command without `--test-only`. It adds the server to `.mcp.json`, and rewrites the « Serveurs MCP » section of the `README.md`: each server, its variables to set, its eval double. Relay the variables the user must set, and the reminder it prints: a skill that depends on this server needs a double in `evals/mocks/<name>/` to be evaluated; without one, the server is not started during an evaluation.

## 4. Green

Run the server's test, then `bash tests/run-all.sh`: the declaration as written, the launcher present and cited, run by `bash`, no imperative install in the declaration nor in the launcher, no secret, the variables documented; `claude plugin validate` checks `.mcp.json` with `plugin.json`. Record both outputs, red then green, in the plugin's `PROGRESS.md`.
