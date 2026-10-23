# shellcheck shell=bash
# A plugin at the model that plugin-plugin did not create, for the tests of add and rebuild, in
# place of the read copies of real plugins (decision i): no .plugin-plugin/, a harness written in
# its own words — run-all.sh, lib.sh —, a skill, a reading agent, a writing agent held by a scope
# guard of its own that knows it by name, the guard's test on simulated inputs, and a test that
# counts its skills and agents. Not copied into the plugins plugin-plugin creates.

# foreign_plugin <dir>: writes plugin-essai 0.3.0 in <dir>, a git repository with one commit.
foreign_plugin() {
  local d=$1 repo=https://github.com/soonlysoul/plugin-essai description="Plugin d'essai : des notes sous docs/."
  mkdir -p "$d/.claude-plugin" "$d/docs" "$d/skills/essai-note" "$d/agents" "$d/hooks/scripts" "$d/tests/static" "$d/tests/hooks"
  jq -n --arg r "$repo" --arg d "$description" '{name: "plugin-essai", version: "0.3.0", description: $d,
    author: {name: "Soon"}, homepage: $r, repository: $r, license: "MIT", keywords: ["essai"]}' >"$d/.claude-plugin/plugin.json"
  jq -n --arg d "$description" '{name: "plugin-essai", description: "Local marketplace for the plugin-essai Claude Code plugin.",
    owner: {name: "Soon"}, plugins: [{name: "plugin-essai", source: "./", description: $d}]}' >"$d/.claude-plugin/marketplace.json"
  sed -E "s/^Copyright \(c\) [0-9]+ Soon$/Copyright (c) $(date +%Y) Soon/" "$PLUGIN_ROOT/LICENSE" >"$d/LICENSE"
  printf 'build/\nevals/**/results/\n' >"$d/.gitignore"
  printf '# plugin-essai\n\nVersion **0.3.0**\n\nLe skill `essai-note`, les agents `essai-reader` et `essai-writer`, le hook `essai-scope`.\n' >"$d/README.md"
  printf '# Journal des versions\n\n## [0.3.0] — 2026-10-01\n\n### Ajouté\n\n- Le skill essai-note et ses agents.\n' >"$d/CHANGELOG.md"
  printf '# PROGRESS — plugin-essai\n' >"$d/PROGRESS.md"
  printf '# Architecture — plugin-essai\n' >"$d/ARCHITECTURE.md"
  printf '# Installation — plugin-essai\n\n```bash\nclaude plugin install plugin-essai@soon --scope user\n```\n' >"$d/docs/INSTALLATION.md"
  printf '# Guide — plugin-essai\n' >"$d/docs/USER_GUIDE.md"
  printf '# Sécurité — plugin-essai\n' >"$d/docs/SECURITY.md"
  printf '# Dépannage — plugin-essai\n' >"$d/docs/TROUBLESHOOTING.md"

  cat >"$d/skills/essai-note/SKILL.md" <<'SKILL'
---
name: essai-note
description: "Write a short note under docs/. Use when Soon asks for a note in the plugin; not for code. « écris une note »."
argument-hint: "[sujet]"
when_to_use: "When a note under docs/ is asked for."
---

# Write a note

Ask for the subject, then let the essai-writer agent write the note.
SKILL
  cat >"$d/agents/essai-reader.md" <<'AGENT'
---
name: essai-reader
description: "Use this agent when a file of the plugin must be read and summarised for the main session, without changing anything; not for writing, which is the task of essai-writer. It returns a short report."
tools: Read, Grep, Glob
model: sonnet
color: blue
---

## Responsibilities

Read the files named and summarise them.

## Approach

Read, then report.

## Output format

STATUS, FILES_CHANGED, COMMANDS_RUN, OPEN_QUESTIONS.
AGENT
  cat >"$d/agents/essai-writer.md" <<'AGENT'
---
name: essai-writer
description: "Use this agent when a note must be written under docs/ from a subject the main session gives; not for code nor for any file outside docs/, which its scope guard refuses. It writes one note and reports."
tools: Read, Write
model: sonnet
color: green
---

## Responsibilities

Write one note under docs/.

## Approach

Read what exists, write the note, report.

## Output format

STATUS, FILES_CHANGED, COMMANDS_RUN, OPEN_QUESTIONS.
AGENT

  jq -n '{description: "plugin-essai guardrails: the scope of essai-writer.",
    hooks: {PreToolUse: [{matcher: "Edit|Write|Bash", hooks: [{type: "command", command: "bash",
      args: ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/essai-scope.sh"], timeout: 10, onFailure: "block"}]}]}}' >"$d/hooks/hooks.json"
  cat >"$d/hooks/scripts/essai-scope.sh" <<'GUARD'
#!/usr/bin/env bash
# Fail-closed: essai-writer writes only under docs/ and runs no shell; every other session and
# agent passes. Exit 2 with a reason on stderr when it blocks, on unreadable input, without jq.
command -v jq >/dev/null 2>&1 || { echo "essai-scope : jq introuvable" >&2; exit 2; }
input=$(cat)
agent=$(jq -r '.agent_type // ""' <<<"$input" 2>/dev/null) || { echo "essai-scope : entrée illisible" >&2; exit 2; }
[[ $agent == plugin-essai:essai-writer ]] || exit 0
tool=$(jq -r '.tool_name // ""' <<<"$input")
path=$(jq -r '.tool_input.file_path // ""' <<<"$input")
[[ $tool != Bash && $path == */docs/* ]] && exit 0
echo "essai-scope : essai-writer n'écrit que sous docs/, sans shell ($tool $path)" >&2
exit 2
GUARD

  cat >"$d/tests/lib.sh" <<'LIB'
# shellcheck shell=bash disable=SC2034
# plugin-essai's own test helpers.
PLUGIN_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPTS="$PLUGIN_ROOT/hooks/scripts"
PASSED=0 FAILED=0
pass() { PASSED=$((PASSED + 1)); printf '  PASS  %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s %s\n' "$1" "${2:-}"; }
# run_hook <script> <stdin> [env assignments...]: HOOK_STATUS and HOOK_STDERR.
run_hook() {
  local script=$1 input=$2
  shift 2
  HOOK_STDERR=$(printf '%s' "$input" | env "$@" "$BASH" "$script" 2>&1 >/dev/null)
  HOOK_STATUS=$?
}
expect_status() { if [[ $HOOK_STATUS == "$2" ]]; then pass "$1"; else fail "$1" "exit $HOOK_STATUS"; fi; }
expect_blocked() { if [[ $HOOK_STATUS == 2 && -n $HOOK_STDERR ]]; then pass "$1"; else fail "$1" "exit $HOOK_STATUS"; fi; }
bash_input() { jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'; }
finish() { printf '%s: %d passed, %d failed\n' "$SUITE" "$PASSED" "$FAILED"; [[ $FAILED == 0 ]]; }
LIB
  cat >"$d/tests/run-all.sh" <<'RUN'
#!/usr/bin/env bash
# plugin-essai's suite: every test of tests/static/ and tests/hooks/; exit 0 when all pass.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
passed=() failed=()
for test in tests/static/test_*.sh tests/hooks/test_*.sh; do
  printf '\n== %s\n' "$test"
  if bash "$test"; then passed+=("$test"); else failed+=("$test"); fi
done
printf '\npassed: %d\nfailed:\n' "${#passed[@]}"
for test in "${failed[@]}"; do printf '  - %s\n' "$test"; done
printf 'blocked:\n'
((${#failed[@]} == 0))
RUN
  cat >"$d/tests/static/test_components.sh" <<'TEST'
#!/usr/bin/env bash
# The components plugin-essai ships: one skill, two agents.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_components
skills=$(find "$PLUGIN_ROOT/skills" -name SKILL.md | wc -l)
[[ $skills == 1 ]] && pass "one skill" || fail "one skill" "$skills"
agents=$(find "$PLUGIN_ROOT/agents" -name '*.md' | wc -l)
[[ $agents == 2 ]] && pass "two agents" || fail "two agents" "$agents"
finish
TEST
  cat >"$d/tests/hooks/test_essai_scope.sh" <<'TEST'
#!/usr/bin/env bash
# essai-scope on simulated inputs.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_essai_scope
HOOK="$SCRIPTS/essai-scope.sh"
writer() { jq -nc --arg t "$1" --arg p "$2" '{agent_type: "plugin-essai:essai-writer", tool_name: $t, tool_input: {file_path: $p}}'; }
run_hook "$HOOK" "$(writer Write /p/src/main.txt)"
expect_blocked "essai-writer hors de docs/ : bloqué"
run_hook "$HOOK" "$(writer Write /p/docs/note.md)"
expect_status "essai-writer sous docs/ : permis" 0
run_hook "$HOOK" "$(bash_input ls)"
expect_status "session principale : permise" 0
run_hook "$HOOK" 'pas du json'
expect_blocked "entrée illisible : bloquée"
finish
TEST
  git -C "$d" init -q -b main && git -C "$d" add -A \
    && git -C "$d" -c user.name=Test -c user.email=test@example.invalid commit -qm "plugin-essai 0.3.0"
}
