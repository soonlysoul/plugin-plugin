#!/usr/bin/env bash
# pp.sh check on plugin-plugin itself, the only real plugin its tests read (decision i): no gap to
# the model of docs/MODEL.md, and nothing changes — HEAD, git status, the sum of every visible
# file. The gaps of a plugin off the model are proven on copies, by tests/static/test_check.sh.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_check_self
PP="$PLUGIN_ROOT/scripts/pp.sh"

# state: HEAD, git status and the sum of every file a clone would carry; git status without the
# index lock, which would rewrite the index.
state() {
  printf '%s|%s|%s' "$(git -C "$PLUGIN_ROOT" rev-parse HEAD 2>/dev/null)" "$(GIT_OPTIONAL_LOCKS=0 git -C "$PLUGIN_ROOT" status --porcelain 2>/dev/null)" \
    "$(cd "$PLUGIN_ROOT" && git -c core.quotepath=off ls-files -co --exclude-standard -z 2>/dev/null | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)"
}

before=$(state)
output=$("$BASH" "$PP" check "$PLUGIN_ROOT" 2>&1)
status=$?
[[ $status == 0 ]] && pass "check sur plugin-plugin : exit 0" || fail "check sur plugin-plugin : exit 0" "exit $status ; $(tr '\n' '|' <<<"$output" | head -c 600)"
grep -qx 'écarts : 0 — au modèle de plugin-plugin (docs/MODEL.md)' <<<"$output" \
  && pass "« écarts : 0 », au modèle de plugin-plugin" || fail "« écarts : 0 », au modèle de plugin-plugin" "$(tr '\n' '|' <<<"$output" | head -c 600)"
[[ $(state) == "$before" ]] && pass "rien n'est modifié : HEAD, git status et empreintes identiques" \
  || fail "rien n'est modifié : HEAD, git status et empreintes identiques"

finish
