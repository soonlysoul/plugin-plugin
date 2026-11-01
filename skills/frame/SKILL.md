---
name: frame
description: "Frame a new plugin before any file of it exists: one question at a time with a reasoned recommendation, then a PRD and an architecture approved explicitly. Use when Soon wants a new plugin; not for an existing one nor an approved framing. « cadre un nouveau plugin », « je veux un plugin qui… »."
argument-hint: "[dossier cible] [besoin en une phrase]"
when_to_use: "Before /plugin-plugin:create."
---

# Frame a plugin

Address the user in French unless they write in another language.

**Questions.** Put a choice among known options in AskUserQuestion, one question per call: two to four options, the recommended one first, its label ending « (Recommandé) », its reason in its description. Put an agreement there too: « Non » then « Oui », none recommended, `answers` never filled in; only « Oui », chosen or typed, with no note, agrees — a note, Escape or any other answer does not. Ask an open question in text. Without AskUserQuestion — a subagent, `claude -p` —, ask every question in text, then stop; a typed « oui » agrees the same.

Nothing of the plugin is written before its PRD and architecture are approved. This skill writes only in the target folder: `docs/PRD.md`, `docs/ARCHITECTURE.md` and `.plugin-plugin/`.

**Checkpoint.** Once the state exists (step 1), run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" checkpoint <folder> start --skill frame --steps "Dossier et état|Interview|Documents en brouillon|Approbations|Passage à create"`. After each step: `… checkpoint <folder> done <n> --command "<command or action>" --exit <code>`; on a blocker: `… checkpoint <folder> block "<reason>"`. A refused `start` means a framing of this folder was interrupted: resume it from its next step, and use `--restart` only when Soon abandons it. The same command failing twice the same way: stop and expose the blocker.

## Step 1 — Target folder and state

Take the target folder from the arguments, or ask for it. It must be empty or missing, or hold only a previous framing (`docs/`, `.plugin-plugin/`). Otherwise stop and say why. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" init-state <folder>`; it refuses a folder whose parent is missing.

A previous framing resumes where it stopped, read from the documents (`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" status <document>`):

- no document: step 2;
- a document holding « à trancher »: ask about its first such item;
- a document not `APPROUVÉ`: step 4 for it;
- both `APPROUVÉ`: step 5.

## Step 2 — Interview, one question at a time

Ask exactly one question at a time, then stop and wait. Each question carries your recommendation and its reason in one or two sentences: in AskUserQuestion, the first option. The need, what must stay out of scope and the success criteria are open questions, asked in text; the name, the language of identifiers, each component's kind and what it needs are choices. Cover, in this order: the need and who has it; what must stay out of scope; the name; the language of identifiers; the components; the success criteria. A need given as argument answers the first question: confirm it instead of asking.

- **Name**: propose two or three `plugin-<domaine>`, the best first, each checked with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" check-name <name>`. A refusal names the rule broken: offer another name in its place. Whether the name is free on GitHub is checked at creation.
- **Identifiers**: ask the language of skill and agent names; recommend English.
- **Components**: each one answers a user story. Deterministic checks are hooks or scripts, judgment is a skill, a bounded task is an agent; an existing MCP server can be declared. Settle in the same question what the architecture needs of each — a hook's event and fail-open or fail-closed mode, an agent's tools and write folders — or leave it « à trancher ». Out of the model's scope: MCP server code, channels, output styles, classic commands, plugin options, plugin dependencies, language servers — say so, and say what would reopen them.

When Soon delegates a decision (« tranche le mieux », « comme tu veux »), choose, then record it: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" delegate <folder> --question "<question>" --choice "<choice>" --reason "<reason>"`. Tell Soon the choice and its reason in one line, and go on. An approval is never delegated.

## Step 3 — Write the documents as drafts

Fill `${CLAUDE_PLUGIN_ROOT}/templates/PRD.md` and `${CLAUDE_PLUGIN_ROOT}/templates/ARCHITECTURE.md` into `<folder>/docs/`, keeping their line `**Statut : BROUILLON**`; never fill a template over an existing document. Derive the user stories from the answers on the need and the components. Copy every delegated decision of `.plugin-plugin/decisions.md` into the PRD's « Décisions déléguées », those of later steps included. Write only what the interview settled; mark anything else « à trancher ».

## Step 4 — Approval, document by document

List the items of the PRD still « à trancher »: Soon settles each, or accepts them as they are, explicitly. Present the PRD, then ask for its approval — « Approuver docs/PRD.md ? », « Non » then « Oui » —, and stop. When Soon answers:

- An approval: run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/pp.sh" approve <folder>/docs/PRD.md --quote '<the answer chosen, or Soon's message, verbatim>'` — single quotes, each `'` written `'\''`. Only the script decides.
- The script refuses the message (« ok », « oui mais … »): say that only an explicit approval counts — « oui », « je valide », « j'approuve », « approuvé » — and ask again, changing nothing.
- « Non », a note joined to « Oui », or a requested change: apply it, leave the status as it is, present the document again; no `approve`.

Do the same for the architecture. Change these documents with Edit or Write only, never through Bash: a document modified after its approval then goes back to `REVUE` on its own (hook `doc-status-guard`); present it again before relying on it.

## Step 5 — Hand over

When both documents are `APPROUVÉ`, say so with their approval lines, and give the next step: `/plugin-plugin:create <folder>`. Stop there.
