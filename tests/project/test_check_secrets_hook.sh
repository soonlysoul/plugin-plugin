#!/usr/bin/env bash
# The project's PreToolUse hook check-secrets (.claude/hooks/check-secrets.sh), on a content longer
# than a pipe holds: a secret on its first line is refused as on a short content, a placeholder
# still passes. Fed by a pipe, grep -q leaves at the first match and the writer dies of SIGPIPE;
# under pipefail the test read false. Words are assembled, so that this file names no secret.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_check_secrets_hook
HOOK="$PLUGIN_ROOT/.claude/hooks/check-secrets.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# 200 000 bytes of ordinary lines, three times what a pipe holds; and no tail at all.
yes 'ligne ordinaire' | head -c 200000 >"$work/long"
: >"$work/short"

key=api; key+=_key
word=tok; word+=en
github=gh; github+=p_Zq8vLm2pRt5wYx7nB3cD9fGh1jK4sW6eQ0a
assignment="$key = \"Zq8vLm2pRt5wYx7n\""
placeholder="$key = \"\${MA_CLE_D_API}\""

# write <file_path> <first line> <tail file>: a Write of that line, then the tail.
write() {
  run_hook "$HOOK" "$(jq -nc --arg f "$1" --arg c "$2" --rawfile t "$3" \
    '{tool_name: "Write", tool_input: {file_path: $f, content: ($c + "\n" + $t)}}')"
}
# refused <label> <reason>: the last write is blocked, for that reason.
refused() {
  if [[ $HOOK_STATUS == 2 && $HOOK_STDERR == *"check-secrets.sh : $2"* ]]; then pass "$1"
  else fail "$1" "exit $HOOK_STATUS ; stderr : ${HOOK_STDERR:0:200}"; fi
}
passes() {
  if [[ $HOOK_STATUS == 0 && -z $HOOK_STDERR ]]; then pass "$1"
  else fail "$1" "exit $HOOK_STATUS ; stderr : ${HOOK_STDERR:0:200}"; fi
}

for tail in short long; do
  echo "# contenu $tail"
  write "$work/config.py" "$assignment" "$work/$tail"
  refused "$tail : affectation littérale en première ligne, refusée" "affectation d'un secret à une valeur littérale"
  write "$work/config.py" "$placeholder" "$work/$tail"
  passes "$tail : lecture d'environnement en première ligne, acceptée"
  write "$work/CLAUDE.md" "$word: valeur" "$work/$tail"
  refused "$tail : CLAUDE.md, secret en première ligne, refusé" "ce fichier est explicitement interdit aux secrets"
  write "$work/notes.txt" "$github" "$work/$tail"
  refused "$tail : jeton GitHub en première ligne, refusé" "token GitHub"
  write "$work/notes.txt" "rien de secret ici" "$work/$tail"
  passes "$tail : contenu ordinaire, accepté"
done

finish
