#!/usr/bin/env bash
# consent-capture — UserPromptSubmit hook.
# The message Soon types right after a step announced by pp.sh publish or pp.sh mount is the only
# consent to it. A literal « oui » is written to .plugin-plugin/consents.log for the announcement in
# .plugin-plugin/pending, which gesture-guard then lets through once; any other message withdraws
# the announcement; one left unanswered for 30 minutes is withdrawn. Claude is told which.
# Inert outside a managed project and without an announcement: installed for the account, the hook
# sees every message of every session.
# Fail-open: it always exits 0; hooks.json sets "onFailure": "continue".

command -v jq >/dev/null 2>&1 || exit 0
# shellcheck source=../../scripts/lib/consent.sh
source "${BASH_SOURCE[0]%/*}/../../scripts/lib/consent.sh" 2>/dev/null || exit 0
IFS= read -r -d '' input || true
cwd=$(jq -r '.cwd // empty | strings' <<<"$input" 2>/dev/null) || exit 0
prompt=$(jq -r '.prompt // empty | strings' <<<"$input" 2>/dev/null) || exit 0
project=$(managed_project "$cwd") || exit 0
state="$project/.plugin-plugin"
[[ -f $state/pending ]] && read_pending "$state/pending" || exit 0

stamp=$(date +%FT%T%:z)
tell() { jq -nc --arg m "plugin-plugin : $1" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $m}}'; }
answer() { printf '%s\t%s\t%s\t%s\t%s%s\n' "$stamp" "$1" "$PENDING_ID" "$PENDING_DATE" "$PENDING_SHA" "${2:+	$2}" >>"$state/consents.log"; }

if (($(date +%s%N) - PENDING_DATE > CONSENT_MAX_AGE_NS)); then
  rm -f "$state/pending"
  answer expiré
  tell "l'annonce « $PENDING_ID » est restée plus de 30 minutes sans réponse ; elle est retirée sans accord. Ne pas lancer le geste : l'annoncer de nouveau."
elif answer_is_yes "$prompt"; then
  consented "$project" || answer accord "« oui »"
  tell "« oui » capté pour « $PENDING_ID ». Lancer exactement cette commande, une seule fois : $PENDING_COMMAND"
else
  rm -f "$state/pending"
  answer refus
  tell "la réponse n'est pas un « oui » : l'annonce « $PENDING_ID » est retirée. Ne pas lancer le geste ; il faudra l'annoncer de nouveau."
fi
exit 0
