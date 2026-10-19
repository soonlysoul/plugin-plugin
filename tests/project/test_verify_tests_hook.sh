#!/usr/bin/env bash
# The project's Stop hook (.claude/hooks/verify-tests.sh): a modified or new shell script is
# reported with the suite to run, a clean tree stays silent, the hook never blocks.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_verify_tests_hook
HOOK="$PLUGIN_ROOT/.claude/hooks/verify-tests.sh"
STOP_INPUT='{"session_id":"test","hook_event_name":"Stop","stop_hook_active":false}'

repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
git -C "$repo" init -q
mkdir -p "$repo/tests" "$repo/hooks/scripts"
printf '#!/usr/bin/env bash\n' >"$repo/tests/run-all.sh"
printf '#!/usr/bin/env bash\n' >"$repo/hooks/scripts/guard.sh"
git -C "$repo" add -A
git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm init

echo "# arbre propre"
run_hook "$HOOK" "$STOP_INPUT" CLAUDE_PROJECT_DIR="$repo"
[[ $HOOK_STATUS == 0 && -z $HOOK_STDOUT && -z $HOOK_STDERR ]] && pass "arbre propre : silencieux, exit 0" \
  || fail "arbre propre : silencieux, exit 0" "exit $HOOK_STATUS ; stderr : ${HOOK_STDERR:0:200}"

echo "# script shell modifié"
printf 'echo modifié\n' >>"$repo/hooks/scripts/guard.sh"
run_hook "$HOOK" "$STOP_INPUT" CLAUDE_PROJECT_DIR="$repo"
[[ $HOOK_STATUS == 0 ]] && pass "script modifié : ne bloque pas (exit 0)" || fail "script modifié : ne bloque pas (exit 0)" "exit $HOOK_STATUS"
grep -qF 'hooks/scripts/guard.sh' <<<"$HOOK_STDERR" && pass "script modifié : nommé" \
  || fail "script modifié : nommé" "stderr : ${HOOK_STDERR:0:300}"
grep -qF 'bash tests/run-all.sh' <<<"$HOOK_STDERR" && pass "script modifié : propose bash tests/run-all.sh" \
  || fail "script modifié : propose bash tests/run-all.sh" "stderr : ${HOOK_STDERR:0:300}"
git -C "$repo" checkout -q -- hooks/scripts/guard.sh

echo "# script shell nouveau, dans un dossier nouveau"
mkdir -p "$repo/scripts"
printf '#!/usr/bin/env bash\n' >"$repo/scripts/tool.sh"
run_hook "$HOOK" "$STOP_INPUT" CLAUDE_PROJECT_DIR="$repo"
grep -qF 'scripts/tool.sh' <<<"$HOOK_STDERR" && pass "script nouveau : nommé" \
  || fail "script nouveau : nommé" "exit $HOOK_STATUS ; stderr : ${HOOK_STDERR:0:300}"

finish
