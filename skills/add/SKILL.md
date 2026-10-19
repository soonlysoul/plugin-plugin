---
name: add
description: "Add a component to a plugin of the model — skill with its eval suite, hook on simulated inputs, agent with declared tools, existing MCP server — its test seen failing before it passes; an out-of-scope one is refused. Use when Soon wants a new component in such a plugin; not for framing or creating one. « ajoute un agent à plugin-… »."
argument-hint: "[dossier du plugin] [type] [nom]"
when_to_use: "In a plugin created by /plugin-plugin:create or at the plugin-flutter model."
---

# Add a component

Address the user in French unless they write in another language.

The tool of every step is `${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh`; the references write it `<pp>`.

A component answers a user story of the plugin's PRD; nothing is added « au cas où ». Each one is written test first: the test runs and fails for the right reason, then the component is written and the same test passes. Both outputs are recorded in the plugin's `PROGRESS.md`, with the command and the exit code.

## Step 1 — Plugin and component

Take the plugin folder, the kind and the name from the arguments, or ask for them one at a time. Any other kind — the code of an MCP server, a channel, a language server, an output style, a classic command, a plugin option, a dependency between plugins —: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" out-of-scope <mcp-code|channel|lsp|output-style|command|plugin-option|plugin-dependency>`, relay its refusal — the reason and what would reopen it — and stop. Check the name with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" check-name plugin-<name>` when it names a plugin, and that the component name is kebab-case and free in the plugin.

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" checkpoint <folder> start --skill add --steps "<the steps of the kind>"`. After each step: `… checkpoint <folder> done <n> --command "<command>" --exit <code>`. The same command failing twice the same way: stop and expose the blocker.

## Step 2 — Follow the procedure of the kind

- **Skill**: read `${CLAUDE_PLUGIN_ROOT}/skills/add/reference/skill.md` and follow it.
- **Hook**: read `${CLAUDE_PLUGIN_ROOT}/skills/add/reference/hook.md` and follow it.
- **Agent**: read `${CLAUDE_PLUGIN_ROOT}/skills/add/reference/agent.md` and follow it.
- **MCP server**: read `${CLAUDE_PLUGIN_ROOT}/skills/add/reference/mcp.md` and follow it.

## Step 3 — Close

Run the plugin's suite, `bash tests/run-all.sh` in its folder, and its context cost, `claude --plugin-dir <folder> plugin details <name>`. Report both, with the component's always-on cost; above 1 000 tokens for the plugin, say so. Add the component under « Ajouté » in the « en cours » section at the top of its `CHANGELOG.md`; when the top section is already dated, a release, first open `## [à venir] — en cours` above it — `/plugin-plugin:release` dates it. Then propose a commit with its exact commands, run only on a literal "oui".
