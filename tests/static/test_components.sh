#!/usr/bin/env bash
# The components plugin-plugin itself ships, and how its hooks are wired. Specific to
# plugin-plugin: not copied into the plugins it creates.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_components
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"

echo "# skills"
for skill in reaudit frame create; do
  [[ -f $PLUGIN_ROOT/skills/$skill/SKILL.md ]] && pass "skill $skill présent" || fail "skill $skill présent"
done
grep -qx 'disable-model-invocation: true' "$PLUGIN_ROOT/skills/reaudit/SKILL.md" 2>/dev/null \
  && pass "reaudit ne se lance que sur demande explicite" || fail "reaudit ne se lance que sur demande explicite"

echo "# hooks"
# One line per command hook, fields joined by \x1f (read merges consecutive tabs).
hooks=$(jq -r '.hooks | to_entries[] | .key as $event | .value[] | (.matcher // "") as $m
               | .hooks[] | [$event, $m, (.type // ""), (.command // ""), (.args[0] // ""),
                             (.onFailure // ""), ((.args // []) | length), (.timeout // "")]
               | map(tostring) | join("\u001f")' "$HOOKS_JSON" 2>/dev/null)
# expect_hook <event> <matcher> <script> <onFailure> <timeout>: wired exactly so.
expect_hook() {
  local sep=$'\x1f'
  if grep -qxF "$1$sep$2${sep}command${sep}bash$sep\${CLAUDE_PLUGIN_ROOT}/hooks/scripts/$3$sep$4${sep}1$sep$5" <<<"$hooks"; then
    pass "câblé : $1 [$2] $3 onFailure=$4 timeout=$5"
  else
    fail "câblé : $1 [$2] $3 onFailure=$4 timeout=$5" "hooks : $(tr '\037' ' ' <<<"$hooks")"
  fi
}
expect_hook PostToolUse 'Edit|Write' doc-status-guard.sh continue 10

finish
