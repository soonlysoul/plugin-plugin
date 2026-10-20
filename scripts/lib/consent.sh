# shellcheck shell=bash
# Shared by scripts/pp.sh and the hooks consent-capture and gesture-guard: the consent to a step of
# a publication, kept in <project>/.plugin-plugin/, which git ignores. Tab-separated.
#   pending       the announced step, one line: date of the announcement (nanoseconds), step id,
#                 sha256 of the step's commands, the command Claude types; written by pp.sh only
#   consents.log  the answers to announcements, written by consent-capture only: date, accord,
#                 refus or expiré, step id, date of the announcement, sha256[, quote]
#   gestures.log  the outcome of each gesture, written by pp.sh only

# An announcement left unanswered for longer than this is withdrawn (read by consent-capture).
# shellcheck disable=SC2034
CONSENT_MAX_AGE_NS=$((30 * 60 * 1000000000))

# managed_project <dir>: the nearest directory at or above <dir> that holds .plugin-plugin/.
managed_project() {
  local dir=$1
  [[ $dir == /* ]] || return 1
  while [[ -n $dir ]]; do
    [[ -d $dir/.plugin-plugin ]] && { printf '%s' "$dir"; return 0; }
    dir=${dir%/*}
  done
  [[ -d /.plugin-plugin ]] && printf '/'
}

# answer_is_yes <message>: true for a literal « oui », whatever its case, its surrounding blanks and
# its final punctuation; « ok », « oui mais … » and anything else are not.
answer_is_yes() {
  local text
  text=$(tr '[:upper:]\n\t' '[:lower:]  ' <<<"$1" | sed -E 's/^ +//; s/[ .!]+$//')
  [[ $text == oui ]]
}

# read_pending <file>: PENDING_DATE, PENDING_ID, PENDING_SHA and PENDING_COMMAND, from the
# announcement; false when it is unreadable.
read_pending() {
  IFS=$'\t' read -r PENDING_DATE PENDING_ID PENDING_SHA PENDING_COMMAND <"$1" 2>/dev/null \
    && [[ $PENDING_DATE =~ ^[0-9]+$ && -n $PENDING_ID && -n $PENDING_COMMAND ]]
}

# consented <project>: true when the last answer in consents.log is the « oui » to the announcement
# read by read_pending.
consented() {
  local stamp kind id date sha
  IFS=$'\t' read -r stamp kind id date sha _ < <(tail -n 1 "$1/.plugin-plugin/consents.log" 2>/dev/null)
  [[ $kind == accord && $id == "$PENDING_ID" && $date == "$PENDING_DATE" && $sha == "$PENDING_SHA" ]]
}
