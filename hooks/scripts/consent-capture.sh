#!/usr/bin/env bash
# consent-capture — UserPromptSubmit hook, and PostToolUse hook for AskUserQuestion.
# Soon's answer to a step announced by pp.sh publish or pp.sh mount is the only consent to it: the
# message typed right after it, or the answer chosen in AskUserQuestion to the question the
# announcement gives (« question : … »), which reaches no UserPromptSubmit and is read here in
# PostToolUse, keyed by that exact text. A literal « oui » typed, or « Oui » chosen without a note,
# is written to .plugin-plugin/consents.log for the announcement in .plugin-plugin/pending, which
# gesture-guard then lets through once; any other message or answer withdraws the announcement; one
# left unanswered for 30 minutes is withdrawn. Claude is told which. A notification Claude Code
# submits itself (<task-notification>…) is no answer, nor a question closed by Escape, which
# reaches no hook: the announcement still waits.
# Inert outside a managed project and without an announcement: installed for the account, the hook
# sees every message of every session.
# Fail-open: it always exits 0; hooks.json sets "onFailure": "continue".

command -v jq >/dev/null 2>&1 || exit 0
# shellcheck source=../../scripts/lib/consent.sh
source "${BASH_SOURCE[0]%/*}/../../scripts/lib/consent.sh" 2>/dev/null || exit 0
IFS= read -r -d '' input || true
event=$(jq -r '.hook_event_name // "UserPromptSubmit" | strings' <<<"$input" 2>/dev/null) || exit 0
case $event in
  UserPromptSubmit) ;;
  PostToolUse) [[ $(jq -r '.tool_name // empty | strings' <<<"$input" 2>/dev/null) == AskUserQuestion ]] || exit 0 ;;
  *) exit 0 ;;
esac
cwd=$(jq -r '.cwd // empty | strings' <<<"$input" 2>/dev/null) || exit 0
project=$(managed_project "$cwd") || exit 0
state="$project/.plugin-plugin"
[[ -f $state/pending ]] && read_pending "$state/pending" || exit 0

stamp=$(date +%FT%T%:z)
tell() { jq -nc --arg e "$event" --arg m "plugin-plugin : $1" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $m}}'; }
answer() { printf '%s\t%s\t%s\t%s\t%s%s\n' "$stamp" "$1" "$PENDING_ID" "$PENDING_DATE" "$PENDING_SHA" "${2:+	$2}" >>"$state/consents.log"; }

prompt="" reply="" note="" yes=0
if [[ $event == UserPromptSubmit ]]; then
  prompt=$(jq -r '.prompt // empty | strings' <<<"$input" 2>/dev/null) || exit 0
  answer_is_yes "$prompt" && yes=1 quote="« oui »"
else
  # The answer is read in the tool's response, never in its input, which Claude writes.
  question=$(consent_question "$PENDING_ID")
  reply=$(jq -r --arg q "$question" '.tool_response.answers | objects | .[$q] // empty | strings' <<<"$input" 2>/dev/null) || exit 0
  note=$(jq -r --arg q "$question" '.tool_response.annotations | objects | .[$q] | objects | .notes // empty | strings' <<<"$input" 2>/dev/null) || exit 0
  [[ -z ${note//[[:space:]]/} ]] && answer_is_yes "$reply" && yes=1 quote="« Oui » (AskUserQuestion)"
fi

if (($(date +%s%N) - PENDING_DATE > CONSENT_MAX_AGE_NS)); then
  rm -f "$state/pending"
  answer expiré
  tell "l'annonce « $PENDING_ID » est restée plus de 30 minutes sans réponse ; elle est retirée sans accord. Ne pas lancer le geste : l'annoncer de nouveau."
elif [[ ${prompt#"${prompt%%[![:space:]]*}"} == '<task-notification>'* ]]; then
  tell "une notification de Claude Code n'est pas une réponse : l'annonce « $PENDING_ID » attend toujours celle de Soon. Ne pas lancer le geste avant son « oui »."
elif ((yes)); then
  consented "$project" || answer accord "$quote"
  tell "« oui » capté pour « $PENDING_ID ». Lancer exactement cette commande, une seule fois : $PENDING_COMMAND"
else
  rm -f "$state/pending"
  answer refus
  tell "la réponse n'est pas un « oui » : l'annonce « $PENDING_ID » est retirée. Ne pas lancer le geste ; il faudra l'annoncer de nouveau."
fi
exit 0
