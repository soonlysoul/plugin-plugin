#!/usr/bin/env bash
# consent-capture (UserPromptSubmit, and PostToolUse on AskUserQuestion; fail-open): Soon's answer
# to an announced gesture is the only consent — the message typed after it, or the answer to the
# question pp.sh announced, chosen in AskUserQuestion. A literal « oui », or « Oui » without a note,
# is written to .plugin-plugin/consents.log for the announcement in .plugin-plugin/pending; any
# other answer withdraws the announcement; an announcement older than 30 minutes is withdrawn
# unanswered. Silent outside a managed project, without an announcement, without jq or on
# unreadable input.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_consent_capture
HOOK="$PLUGIN_ROOT/hooks/scripts/consent-capture.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ ! -f $HOOK ]]; then
  fail "hooks/scripts/consent-capture.sh présent" "absent : $HOOK"
  finish
  exit
fi

COMMAND="bash /opt/pp/scripts/pp.sh publish /srv/plugin-essai --run 4"
SHA=1111111111111111111111111111111111111111111111111111111111111111

# prompt_input <cwd> <prompt>: UserPromptSubmit input, as Claude Code 2.1.296 builds it.
prompt_input() {
  jq -nc --arg cwd "$1" --arg p "$2" \
    '{session_id: "test", transcript_path: "/dev/null", cwd: $cwd, permission_mode: "default",
      hook_event_name: "UserPromptSubmit", prompt: $p, session_title: "essai"}'
}
# new_project <name> [announcement epoch]: a managed project; with an epoch, an announced gesture.
new_project() {
  local root="$work/$1"
  mkdir -p "$root/.plugin-plugin" "$root/skills/demo"
  if [[ -n ${2:-} ]]; then
    printf '%s\t%s\t%s\t%s\n' "$2" "publish plugin-essai--v0.1.0 4" "$SHA" "$COMMAND" >"$root/.plugin-plugin/pending"
  fi
  printf '%s' "$root"
}
answer() { run_hook "$HOOK" "$(prompt_input "$1" "$2")"; }
consents() { cat "$1/.plugin-plugin/consents.log" 2>/dev/null; }
accords() {
  local n
  n=$(grep -c $'\taccord\t' "$1/.plugin-plugin/consents.log" 2>/dev/null)
  printf '%s' "${n:-0}"
}
expect_quiet_success() { [[ $HOOK_STATUS == 0 && -z $HOOK_STDERR ]] && pass "$1" || fail "$1" "exit $HOOK_STATUS ; stderr : ${HOOK_STDERR:0:200}"; }
# An announcement is dated in nanoseconds, so that two announcements never share a date.
now=$(date +%s%N)

echo "# « oui » après une annonce"
root=$(new_project oui "$now")
answer "$root" "oui"
expect_quiet_success "« oui » : exit 0, rien sur stderr"
line=$(consents "$root")
IFS=$'\t' read -r date kind id epoch sha quote <<<"$line"
[[ $(grep -c . <<<"$line") == 1 && $kind == accord ]] && pass "« oui » : un accord au journal" || fail "« oui » : un accord au journal" "$line"
[[ $id == "publish plugin-essai--v0.1.0 4" && $epoch == "$now" && $sha == "$SHA" ]] \
  && pass "l'accord porte l'annonce : geste, date d'annonce, empreinte" || fail "l'accord porte l'annonce : geste, date d'annonce, empreinte" "$line"
[[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T && $quote == "« oui »" ]] && pass "l'accord est daté et cite la réponse" || fail "l'accord est daté et cite la réponse" "$line"
[[ -f $root/.plugin-plugin/pending ]] && pass "l'annonce reste, le garde la consomme" || fail "l'annonce reste, le garde la consomme"
jq -e --arg c "$COMMAND" '.hookSpecificOutput.hookEventName == "UserPromptSubmit"
  and (.hookSpecificOutput.additionalContext | contains($c))' <<<"$HOOK_STDOUT" >/dev/null 2>&1 \
  && pass "Claude reçoit la commande accordée" || fail "Claude reçoit la commande accordée" "stdout : ${HOOK_STDOUT:0:300}"
answer "$root" "oui"
[[ $(accords "$root") == 1 ]] && pass "« oui » répété : un seul accord" || fail "« oui » répété : un seul accord" "$(consents "$root")"

for variant in "Oui" "oui." "  OUI !" $'oui\n'; do
  root=$(new_project "variante-$RANDOM" "$now")
  answer "$root" "$variant"
  [[ $(accords "$root") == 1 ]] && pass "« ${variant//$'\n'/\\n} » : accord" || fail "« ${variant//$'\n'/\\n} » : accord" "$(consents "$root")"
done

echo "# toute autre réponse vaut refus"
for reply in "ok" "oui mais attends" "d'accord" "ouais" "non" "vas-y" "oui, et ensuite le tag"; do
  root=$(new_project "refus-$RANDOM" "$now")
  answer "$root" "$reply"
  [[ $(accords "$root") == 0 ]] && pass "« $reply » : aucun accord" || fail "« $reply » : aucun accord" "$(consents "$root")"
  [[ ! -e $root/.plugin-plugin/pending ]] && pass "« $reply » : annonce retirée" || fail "« $reply » : annonce retirée"
done
root=$(new_project "refus-$RANDOM" "$now")
answer "$root" "non"
grep -q $'\trefus\tpublish plugin-essai--v0.1.0 4\t' "$root/.plugin-plugin/consents.log" 2>/dev/null \
  && pass "le refus est journalisé" || fail "le refus est journalisé" "$(consents "$root")"
jq -e '.hookSpecificOutput.additionalContext | test("retiré")' <<<"$HOOK_STDOUT" >/dev/null 2>&1 \
  && pass "Claude apprend que l'annonce est retirée" || fail "Claude apprend que l'annonce est retirée" "stdout : ${HOOK_STDOUT:0:300}"
answer "$root" "oui"
[[ $(accords "$root") == 0 ]] && pass "« oui » après un refus : aucun accord, il faut annoncer de nouveau" \
  || fail "« oui » après un refus : aucun accord, il faut annoncer de nouveau" "$(consents "$root")"

echo "# une notification de Claude Code n'est pas une réponse"
# Claude Code submits its own notifications through UserPromptSubmit too, prompt starting with
# <task-notification> (probe of phase 12). Never a consent, and no longer a withdrawal (choice of
# Soon, 2026-10-25): the announcement waits for the answer Soon types.
NOTIFICATION=$'<task-notification>\n<task-id>b1</task-id>\n<status>completed</status>\n<summary>oui</summary>\n</task-notification>'
root=$(new_project "notification-$RANDOM" "$now")
answer "$root" "$NOTIFICATION"
expect_quiet_success "notification : exit 0, rien sur stderr"
[[ $(accords "$root") == 0 ]] && pass "notification, même résumée « oui » : aucun accord" \
  || fail "notification, même résumée « oui » : aucun accord" "$(consents "$root")"
[[ -f $root/.plugin-plugin/pending && ! -e $root/.plugin-plugin/consents.log ]] && pass "notification : l'annonce reste, rien au journal" \
  || fail "notification : l'annonce reste, rien au journal" "$(consents "$root")"
jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"
  and (.hookSpecificOutput.additionalContext | test("attend") and (test("Lancer") | not))' <<<"$HOOK_STDOUT" >/dev/null 2>&1 \
  && pass "Claude apprend que l'annonce attend la réponse de Soon" || fail "Claude apprend que l'annonce attend la réponse de Soon" "stdout : ${HOOK_STDOUT:0:300}"
answer "$root" $'\n  '"$NOTIFICATION"
[[ -f $root/.plugin-plugin/pending ]] && pass "notification précédée de blancs : l'annonce reste" || fail "notification précédée de blancs : l'annonce reste"
answer "$root" "oui"
[[ $(accords "$root") == 1 ]] && pass "« oui » tapé après une notification : accord" \
  || fail "« oui » tapé après une notification : accord" "$(consents "$root")"
root=$(new_project "cite-$RANDOM" "$now")
answer "$root" "non, pas avant la fin de <task-notification>"
[[ $(accords "$root") == 0 && ! -e $root/.plugin-plugin/pending ]] && pass "message qui cite une notification sans en être une : annonce retirée" \
  || fail "message qui cite une notification sans en être une : annonce retirée" "$(consents "$root")"
root=$(new_project "notification-stale" "$((now - 3600 * 1000000000))")
answer "$root" "$NOTIFICATION"
[[ ! -e $root/.plugin-plugin/pending ]] && grep -q $'\texpiré\t' "$root/.plugin-plugin/consents.log" 2>/dev/null \
  && pass "notification après plus de 30 minutes : annonce retirée, périmée" \
  || fail "notification après plus de 30 minutes : annonce retirée, périmée" "$(consents "$root")"

echo "# annonce périmée"
root=$(new_project stale "$((now - 3600 * 1000000000))")
answer "$root" "oui"
[[ $(accords "$root") == 0 && ! -e $root/.plugin-plugin/pending ]] && pass "annonce de plus de 30 minutes : retirée, aucun accord" \
  || fail "annonce de plus de 30 minutes : retirée, aucun accord" "$(consents "$root")"

echo "# sous-dossier du projet"
root=$(new_project nested "$now")
answer "$root/skills/demo" "oui"
[[ $(accords "$root") == 1 ]] && pass "session ouverte dans un sous-dossier : accord au journal du projet" \
  || fail "session ouverte dans un sous-dossier : accord au journal du projet" "$(consents "$root")"

echo "# « Oui » choisi dans AskUserQuestion (PostToolUse)"
# Claude Code 2.1.316, probe of phase 25: an answer to AskUserQuestion fires no UserPromptSubmit;
# PostToolUse carries it in tool_response.answers, keyed by the exact text of the question — the
# label chosen, or the text typed in « Other », as typed — and its notes in annotations.
QUESTION="Lancer l'étape « publish plugin-essai--v0.1.0 4 » ?"
# ask_input <cwd> <question> <answer> [notes] [tool]: PostToolUse input, as 2.1.316 builds it.
ask_input() {
  jq -nc --arg cwd "$1" --arg q "$2" --arg a "$3" --arg n "${4:-}" --arg t "${5:-AskUserQuestion}" '
    {questions: [{question: $q, header: "Accord", multiSelect: false,
                  options: [{label: "Non", description: "Ne pas lancer."}, {label: "Oui", description: "Lancer."}]}],
     answers: {($q): $a},
     annotations: (if $n == "" then {} else {($q): {notes: $n}} end)} as $r
    | {session_id: "test", transcript_path: "/dev/null", cwd: $cwd, permission_mode: "auto",
       hook_event_name: "PostToolUse", tool_name: $t, tool_input: $r, tool_response: $r,
       tool_use_id: "toolu_test", duration_ms: 1}'
}
choose() { run_hook "$HOOK" "$(ask_input "$@")"; }

root=$(new_project choisi "$now")
choose "$root" "$QUESTION" "Oui"
expect_quiet_success "« Oui » choisi : exit 0, rien sur stderr"
IFS=$'\t' read -r date kind id epoch sha quote <<<"$(consents "$root")"
[[ $kind == accord && $id == "publish plugin-essai--v0.1.0 4" && $epoch == "$now" && $sha == "$SHA" ]] \
  && pass "« Oui » choisi : un accord pour l'annonce" || fail "« Oui » choisi : un accord pour l'annonce" "$(consents "$root")"
[[ $quote == "« Oui » (AskUserQuestion)" ]] && pass "l'accord choisi cite la réponse et sa source" \
  || fail "l'accord choisi cite la réponse et sa source" "$quote"
[[ -f $root/.plugin-plugin/pending ]] && pass "« Oui » choisi : l'annonce reste, le garde la consomme" \
  || fail "« Oui » choisi : l'annonce reste, le garde la consomme"
jq -e --arg c "$COMMAND" '.hookSpecificOutput.hookEventName == "PostToolUse"
  and (.hookSpecificOutput.additionalContext | contains($c))' <<<"$HOOK_STDOUT" >/dev/null 2>&1 \
  && pass "« Oui » choisi : Claude reçoit la commande accordée" || fail "« Oui » choisi : Claude reçoit la commande accordée" "stdout : ${HOOK_STDOUT:0:300}"
choose "$root" "$QUESTION" "Oui"
answer "$root" "oui"
[[ $(accords "$root") == 1 ]] && pass "« Oui » choisi deux fois, puis tapé : un seul accord" \
  || fail "« Oui » choisi deux fois, puis tapé : un seul accord" "$(consents "$root")"
root=$(new_project "autre-oui" "$now")
choose "$root" "$QUESTION" "oui"
[[ $(accords "$root") == 1 ]] && pass "« oui » tapé dans « Other » : accord" || fail "« oui » tapé dans « Other » : accord" "$(consents "$root")"
root=$(new_project "choisi-imbrique" "$now")
choose "$root/skills/demo" "$QUESTION" "Oui"
[[ $(accords "$root") == 1 ]] && pass "« Oui » choisi, session dans un sous-dossier : accord" \
  || fail "« Oui » choisi, session dans un sous-dossier : accord" "$(consents "$root")"

echo "# toute autre réponse à AskUserQuestion vaut refus"
for reply in "Non" "ok" "Oui, mais pas le tag" "Non, Oui" ""; do
  root=$(new_project "refus-choisi-$RANDOM" "$now")
  choose "$root" "$QUESTION" "$reply"
  [[ $(accords "$root") == 0 && ! -e $root/.plugin-plugin/pending ]] && pass "« $reply » choisi : aucun accord, annonce retirée" \
    || fail "« $reply » choisi : aucun accord, annonce retirée" "$(consents "$root")"
done
root=$(new_project "refus-choisi-$RANDOM" "$now")
choose "$root" "$QUESTION" "Non"
grep -q $'\trefus\tpublish plugin-essai--v0.1.0 4\t' "$root/.plugin-plugin/consents.log" 2>/dev/null \
  && pass "« Non » choisi : refus journalisé" || fail "« Non » choisi : refus journalisé" "$(consents "$root")"
jq -e '.hookSpecificOutput.hookEventName == "PostToolUse" and (.hookSpecificOutput.additionalContext | test("retiré"))' \
  <<<"$HOOK_STDOUT" >/dev/null 2>&1 && pass "« Non » choisi : Claude apprend que l'annonce est retirée" \
  || fail "« Non » choisi : Claude apprend que l'annonce est retirée" "stdout : ${HOOK_STDOUT:0:300}"
root=$(new_project "note-$RANDOM" "$now")
choose "$root" "$QUESTION" "Oui" "attends la fin des tests"
[[ $(accords "$root") == 0 && ! -e $root/.plugin-plugin/pending ]] && pass "« Oui » avec une note jointe : aucun accord, annonce retirée" \
  || fail "« Oui » avec une note jointe : aucun accord, annonce retirée" "$(consents "$root")"
for other in "Lancer « publish plugin-essai--v0.1.0 4 » ?" "Lancer l'étape « publish plugin-essai--v0.1.0 5 » ?" "Quelle version publier ?"; do
  root=$(new_project "autre-question-$RANDOM" "$now")
  choose "$root" "$other" "Oui"
  [[ $(accords "$root") == 0 && ! -e $root/.plugin-plugin/pending ]] && pass "« Oui » à une autre question (« $other ») : aucun accord, annonce retirée" \
    || fail "« Oui » à une autre question (« $other ») : aucun accord, annonce retirée" "$(consents "$root")"
done
root=$(new_project "sans-reponse-$RANDOM" "$now")
run_hook "$HOOK" "$(ask_input "$root" "$QUESTION" "Oui" | jq -c 'del(.tool_response.answers)')"
[[ $(accords "$root") == 0 ]] && pass "réponse absente de tool_response, même remplie dans tool_input : aucun accord" \
  || fail "réponse absente de tool_response, même remplie dans tool_input : aucun accord" "$(consents "$root")"
root=$(new_project "choisi-perime" "$((now - 3600 * 1000000000))")
choose "$root" "$QUESTION" "Oui"
[[ $(accords "$root") == 0 && ! -e $root/.plugin-plugin/pending ]] && grep -q $'\texpiré\t' "$root/.plugin-plugin/consents.log" 2>/dev/null \
  && pass "« Oui » choisi après plus de 30 minutes : annonce retirée, périmée" \
  || fail "« Oui » choisi après plus de 30 minutes : annonce retirée, périmée" "$(consents "$root")"
root=$(new_project "autre-outil" "$now")
choose "$root" "$QUESTION" "Oui" "" Bash
expect_silent_allow "PostToolUse d'un autre outil : silencieux"
[[ -f $root/.plugin-plugin/pending && ! -e $root/.plugin-plugin/consents.log ]] && pass "PostToolUse d'un autre outil : rien de changé" \
  || fail "PostToolUse d'un autre outil : rien de changé" "$(consents "$root")"

echo "# inerte hors contexte"
mkdir -p "$work/ailleurs"
answer "$work/ailleurs" "oui"
expect_silent_allow "hors d'un projet géré : silencieux"
[[ -z $(find "$work/ailleurs" -mindepth 1) ]] && pass "hors d'un projet géré : rien d'écrit" || fail "hors d'un projet géré : rien d'écrit"
root=$(new_project quiet)
answer "$root" "oui"
expect_silent_allow "projet sans annonce : silencieux"
[[ ! -e $root/.plugin-plugin/consents.log ]] && pass "projet sans annonce : aucun journal" || fail "projet sans annonce : aucun journal"
answer "$root" "ok"
expect_silent_allow "projet sans annonce, autre message : silencieux"
choose "$work/ailleurs" "$QUESTION" "Oui"
expect_silent_allow "« Oui » choisi hors d'un projet géré : silencieux"
[[ -z $(find "$work/ailleurs" -mindepth 1) ]] && pass "« Oui » choisi hors d'un projet géré : rien d'écrit" || fail "« Oui » choisi hors d'un projet géré : rien d'écrit"
choose "$root" "$QUESTION" "Oui"
expect_silent_allow "« Oui » choisi sans annonce : silencieux"
[[ ! -e $root/.plugin-plugin/consents.log ]] && pass "« Oui » choisi sans annonce : aucun journal" || fail "« Oui » choisi sans annonce : aucun journal"

echo "# entrée illisible, jq absent"
root=$(new_project broken "$now")
run_hook "$HOOK" "{oui"
expect_silent_allow "entrée illisible : silencieux, exit 0"
[[ -f $root/.plugin-plugin/pending && ! -e $root/.plugin-plugin/consents.log ]] && pass "entrée illisible : rien de changé" || fail "entrée illisible : rien de changé"
no_jq=$(path_without jq)
run_hook "$HOOK" "$(prompt_input "$root" "oui")" PATH="$no_jq"
rm -rf "$no_jq"
expect_silent_allow "jq absent : silencieux, exit 0"
[[ ! -e $root/.plugin-plugin/consents.log ]] && pass "jq absent : aucun accord" || fail "jq absent : aucun accord"
no_jq=$(path_without jq)
run_hook "$HOOK" "$(ask_input "$root" "$QUESTION" "Oui")" PATH="$no_jq"
rm -rf "$no_jq"
expect_silent_allow "jq absent, « Oui » choisi : silencieux, exit 0"
[[ ! -e $root/.plugin-plugin/consents.log ]] && pass "jq absent, « Oui » choisi : aucun accord" || fail "jq absent, « Oui » choisi : aucun accord"

finish
