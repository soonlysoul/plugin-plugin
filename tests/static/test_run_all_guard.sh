#!/usr/bin/env bash
# test_run_all.sh copies the plugin it is pointed at; pointed at anything but a plugin — a lib.sh
# that leaves PLUGIN_ROOT empty made it copy / on 2026-10-20 —, it stops before copying anything.
# The folder used here is a small one: the case never risks the real failure.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_run_all_guard

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/pas-un-plugin" && echo x >"$work/pas-un-plugin/note"

output=$(PLUGIN_UNDER_TEST="$work/pas-un-plugin" timeout 60 "$BASH" "$PLUGIN_ROOT/tests/static/test_run_all.sh" 2>&1)
status=$?
[[ $status == 2 ]] && pass "PLUGIN_ROOT hors d'un plugin : exit 2" || fail "PLUGIN_ROOT hors d'un plugin : exit 2" "exit $status ; $(tail -n 3 <<<"$output" | tr '\n' '|')"
grep -q "n'est pas un plugin" <<<"$output" && pass "la cause est dite" || fail "la cause est dite" "$(head -n 3 <<<"$output" | tr '\n' '|')"
grep -qE '^  (ok|ÉCHEC) ' <<<"$output" && fail "rien n'est copié ni lancé" "$(grep -E '^  (ok|ÉCHEC) ' <<<"$output" | head -n 2)" \
  || pass "rien n'est copié ni lancé"

finish
