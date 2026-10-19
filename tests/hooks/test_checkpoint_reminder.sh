#!/usr/bin/env bash
# checkpoint-reminder (Stop): reminds Claude once to update .plugin-plugin/checkpoint.md when it
# is older than the last commit or than an uncommitted change; silent without a state folder,
# when stop_hook_active is true, or when the checkpoint is up to date. Never fails.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_checkpoint_reminder
HOOK="$PLUGIN_ROOT/hooks/scripts/checkpoint-reminder.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

if [[ ! -f $HOOK ]]; then
  fail "hooks/scripts/checkpoint-reminder.sh présent" "absent : $HOOK"
  finish
  exit
fi

stop_input() {
  jq -nc --arg d "$1" --argjson a "${2:-false}" \
    '{session_id: "test", cwd: $d, hook_event_name: "Stop", permission_mode: "default", stop_hook_active: $a, last_assistant_message: "fini"}'
}
# project <name>: a git repository with one commit and a checkpoint older than nothing.
project() {
  local root="$work/$1"
  mkdir -p "$root/.plugin-plugin"
  git -C "$root" init -q -b main
  echo a >"$root/a.txt"
  git -C "$root" add a.txt && git -C "$root" commit -qm init
  printf '# Point de reprise\n' >"$root/.plugin-plugin/checkpoint.md"
  touch -d '+2 seconds' "$root/.plugin-plugin/checkpoint.md"
  printf '%s' "$root"
}
expect_reminder() {
  if [[ $HOOK_STATUS == 0 ]] && jq -e '.hookSpecificOutput.hookEventName == "Stop" and (.hookSpecificOutput.additionalContext | test("checkpoint"))' \
    <<<"$HOOK_STDOUT" >/dev/null 2>&1; then pass "$1"
  else fail "$1" "exit $HOOK_STATUS ; stdout : ${HOOK_STDOUT:0:300}"; fi
}

echo "# point de reprise à jour"
root=$(project fresh)
run_hook "$HOOK" "$(stop_input "$root")" CLAUDE_PROJECT_DIR="$root"
expect_silent_allow "point à jour : silencieux"

echo "# commit plus récent"
root=$(project newer-commit)
touch -d '-1 hour' "$root/.plugin-plugin/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$root")" CLAUDE_PROJECT_DIR="$root"
expect_reminder "commit plus récent : un rappel"
grep -q "$(git -C "$root" rev-parse --short HEAD)" <<<"$HOOK_STDOUT" && pass "le rappel nomme le commit" || fail "le rappel nomme le commit"
run_hook "$HOOK" "$(stop_input "$root" true)" CLAUDE_PROJECT_DIR="$root"
expect_silent_allow "stop_hook_active : silencieux, un seul rappel"

echo "# fichier modifié plus récent"
root=$(project newer-change)
echo b >>"$root/a.txt"
touch -d '+1 hour' "$root/a.txt"
run_hook "$HOOK" "$(stop_input "$root")" CLAUDE_PROJECT_DIR="$root"
expect_reminder "fichier modifié plus récent : un rappel"
grep -qF 'a.txt' <<<"$HOOK_STDOUT" && pass "le rappel nomme le fichier" || fail "le rappel nomme le fichier"
root=$(project state-only)
printf -- '- décision\n' >"$root/.plugin-plugin/decisions.md"
touch -d '+1 hour' "$root/.plugin-plugin/decisions.md"
run_hook "$HOOK" "$(stop_input "$root")" CLAUDE_PROJECT_DIR="$root"
expect_silent_allow "seul .plugin-plugin/ a changé : silencieux"

echo "# hors de son contexte"
plain="$work/plain"
mkdir -p "$plain"
git -C "$plain" init -q -b main
run_hook "$HOOK" "$(stop_input "$plain")" CLAUDE_PROJECT_DIR="$plain"
expect_silent_allow "sans dossier d'état : silencieux"
root=$(project no-checkpoint)
rm -f "$root/.plugin-plugin/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$root")" CLAUDE_PROJECT_DIR="$root"
expect_silent_allow "sans point de reprise : silencieux"
root=$(project from-cwd)
touch -d '-1 hour' "$root/.plugin-plugin/checkpoint.md"
run_hook "$HOOK" "$(stop_input "$root")"
expect_reminder "sans CLAUDE_PROJECT_DIR : la racine vient de cwd"

echo "# ne jamais échouer"
run_hook "$HOOK" 'pas du json'
expect_status "entrée illisible : exit 0" 0
no_jq=$(path_without jq)
run_hook "$HOOK" "$(stop_input "$root")" PATH="$no_jq" CLAUDE_PROJECT_DIR="$root"
expect_status "jq absent : exit 0" 0
rm -rf "$no_jq"

finish
