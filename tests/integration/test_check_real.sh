#!/usr/bin/env bash
# pp.sh check on the real plugins, from their read copies in build/ref/ (PP_REF_DIR elsewhere):
# plugin-flutter has no gap, plugin-nixos shows its hooks and harness, the old flutter-forge —
# plugin-flutter before its rename — its name; no file of the copies changes. Skipped without them.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_check_real
PP="$PLUGIN_ROOT/scripts/pp.sh"
REF=${PP_REF_DIR:-$PLUGIN_ROOT/build/ref}

if [[ ! -d $REF/plugin-flutter/.git || ! -d $REF/plugin-nixos/.git ]]; then
  skip "check sur les plugins réels" "copies de lecture absentes de $REF"
  finish
  exit
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# state <repo>: HEAD, git status and the sum of every file, .git included.
state() {
  printf '%s|%s|%s' "$(git -C "$1" rev-parse HEAD)" "$(git -C "$1" status --porcelain)" \
    "$(cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
}
run_check() {
  PP_OUTPUT=$("$BASH" "$PP" check "$1" 2>&1)
  PP_STATUS=$?
}

# The old flutter-forge: the last commit of plugin-flutter before its rename.
git -C "$REF/plugin-flutter" archive 04ba88f | tar -x -C "$work" \
  && [[ $(jq -r .name "$work/.claude-plugin/plugin.json") == flutter-forge ]] \
  && pass "ancien flutter-forge extrait (plugin-flutter à 04ba88f)" || fail "ancien flutter-forge extrait (plugin-flutter à 04ba88f)"

flutter_before=$(state "$REF/plugin-flutter") nixos_before=$(state "$REF/plugin-nixos")

echo "# plugin-flutter"
run_check "$REF/plugin-flutter"
[[ $PP_STATUS == 0 ]] && grep -q '^écarts : 0' <<<"$PP_OUTPUT" && pass "aucun écart" \
  || fail "aucun écart" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 600)"

echo "# plugin-nixos"
run_check "$REF/plugin-nixos"
[[ $PP_STATUS == 1 ]] && pass "écarts : exit 1" || fail "écarts : exit 1" "exit $PP_STATUS"
for pattern in '\[forme des hooks\] PreToolUse .*garde-nixos\.sh' '\[arborescence des hooks\] hooks/garde-nixos\.sh' \
  '\[hooks\] PreToolUse .*onFailure non déclaré' '\[harnais\] tests/test_garde\.sh'; do
  grep -qE "$pattern" <<<"$PP_OUTPUT" && pass "écart listé : $pattern" || fail "écart listé : $pattern" "$(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 600)"
done

echo "# ancien flutter-forge"
run_check "$work"
[[ $PP_STATUS == 1 ]] && grep -q 'nom hors format : « flutter-forge » n.a pas le préfixe plugin-' <<<"$PP_OUTPUT" \
  && pass "nom hors format" || fail "nom hors format" "exit $PP_STATUS ; $(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 400)"

echo "# rien n'est modifié"
[[ $(state "$REF/plugin-flutter") == "$flutter_before" ]] && pass "plugin-flutter : HEAD, git status et empreintes identiques" \
  || fail "plugin-flutter : HEAD, git status et empreintes identiques"
[[ $(state "$REF/plugin-nixos") == "$nixos_before" ]] && pass "plugin-nixos : HEAD, git status et empreintes identiques" \
  || fail "plugin-nixos : HEAD, git status et empreintes identiques"

finish
