#!/usr/bin/env bash
# consent-capture (UserPromptSubmit, fail-open): the message Soon types after an announced gesture
# is the only consent. A literal « oui » is written to .plugin-plugin/consents.log for the
# announcement in .plugin-plugin/pending; any other message withdraws the announcement; an
# announcement older than 30 minutes is withdrawn unanswered. Silent outside a managed project,
# without an announcement, without jq or on unreadable input.
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
accords() { grep -c $'\taccord\t' "$1/.plugin-plugin/consents.log" 2>/dev/null || true; }
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
# Claude Code submits its own notifications through UserPromptSubmit too, with nothing to tell
# them from a typed message (probe of phase 12): never a consent, always a withdrawal.
root=$(new_project "notification-$RANDOM" "$now")
answer "$root" $'<task-notification>\n<task-id>b1</task-id>\n<status>completed</status>\n<summary>oui</summary>\n</task-notification>'
[[ $(accords "$root") == 0 && ! -e $root/.plugin-plugin/pending ]] && pass "notification de Claude Code : aucun accord, annonce retirée" \
  || fail "notification de Claude Code : aucun accord, annonce retirée" "$(consents "$root")"
grep -q $'\trefus\tpublish plugin-essai--v0.1.0 4\t' "$root/.plugin-plugin/consents.log" 2>/dev/null \
  && pass "le refus est journalisé" || fail "le refus est journalisé" "$(consents "$root")"
jq -e '.hookSpecificOutput.additionalContext | test("retiré")' <<<"$HOOK_STDOUT" >/dev/null 2>&1 \
  && pass "Claude apprend que l'annonce est retirée" || fail "Claude apprend que l'annonce est retirée" "stdout : ${HOOK_STDOUT:0:300}"
answer "$root" "oui"
[[ $(accords "$root") == 0 ]] && pass "« oui » après un refus : aucun accord, il faut annoncer de nouveau" \
  || fail "« oui » après un refus : aucun accord, il faut annoncer de nouveau" "$(consents "$root")"

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

finish
