---
name: frame
description: "Frame a new Claude Code plugin before any file of it is written: one question at a time with a reasoned recommendation, then a PRD and an architecture approved explicitly. Use when Soon wants a new plugin; not for changing an existing one. « je veux un plugin pour … », « cadre un nouveau plugin »."
argument-hint: "[dossier cible] [besoin en une phrase]"
when_to_use: "Before /plugin-plugin:create, for a plugin that does not exist yet."
---

# Frame a plugin

Address the user in French unless they write in another language.

Nothing of the plugin is written before its PRD and architecture are approved. This skill writes only in the target folder: `docs/PRD.md`, `docs/ARCHITECTURE.md` and `.plugin-plugin/`.

## Step 1 — Target folder and state

Take the target folder from the arguments, or ask for it. It must be empty, or hold only a previous framing (`docs/`, `.plugin-plugin/`). Otherwise stop and say why.

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" init-state <folder>`. When `docs/PRD.md` already exists, read its status with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" status <folder>/docs/PRD.md` and resume from the first open question.

## Step 2 — Interview, one question at a time

Ask exactly one question per message, then stop and wait. Each question carries your recommendation and its reason in one or two sentences. Cover, in this order: the need and who has it; what must stay out of scope; the name; the language of identifiers; the components; the success criteria.

- **Name**: propose `plugin-<domaine>` and check it with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" check-name <name>`. A refusal names the rule broken: propose another name.
- **Identifiers**: ask the language of skill and agent names; recommend English.
- **Components**: each one answers a user story. Deterministic checks are hooks or scripts, judgment is a skill, a bounded task is an agent. Out of the model's scope: MCP server code, channels, output styles, classic commands, plugin options, plugin dependencies, language servers — say so, and say what would reopen them.

When Soon delegates a decision (« tranche le mieux », « comme tu veux »), choose, then record it: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" delegate <folder> --question "<question>" --choice "<choice>" --reason "<reason>"`. Tell Soon the choice and its reason in one line, and go on.

## Step 3 — Write the documents as drafts

Fill `${CLAUDE_PLUGIN_ROOT}/templates/PRD.md` and `${CLAUDE_PLUGIN_ROOT}/templates/ARCHITECTURE.md` into `<folder>/docs/`, keeping their line `**Statut : BROUILLON**`. Copy every delegated decision of `.plugin-plugin/decisions.md` into the PRD's « Décisions déléguées ». Write only what the interview settled; mark anything else « à trancher ».

## Step 4 — Approval, document by document

Present the PRD, then ask for its approval in text, and stop. When Soon answers:

- Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" approve <folder>/docs/PRD.md --quote "<Soon's message, verbatim>"`. Only the script decides: it accepts an explicit approval (« je valide », « oui », « j'approuve »…) and refuses anything else, « ok » or « oui mais … » included.
- On a refusal or a requested change: apply the change, leave the status as it is, present the document again.

Do the same for the architecture. A document modified after its approval goes back to `REVUE` on its own (hook `doc-status-guard`): present it again before relying on it.

## Step 5 — Hand over

When both documents are `APPROUVÉ`, say so with their approval lines, and give the next step: `/plugin-plugin:create <folder>`. Stop there.
