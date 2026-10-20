#!/usr/bin/env bash
# pp.sh rebuild: an existing plugin rebuilt in a folder of its own — the scaffolding plugin-plugin
# produces, its content imported as is from the original's last commit — passes its own suite and
# the strict validation, with no gap between the scaffolding and the original's; the original
# never changes (US-19). Runs on plugin-flutter's read copy (build/ref/, PP_REF_DIR elsewhere);
# skipped without it.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_rebuild
PP="$PLUGIN_ROOT/scripts/pp.sh"
REF=${PP_REF_DIR:-$PLUGIN_ROOT/build/ref}

if [[ ! -d $REF/plugin-flutter/.git ]]; then
  skip "reconstruction de plugin-flutter" "copie de lecture absente de $REF/plugin-flutter"
  finish
  exit
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GIT_CEILING_DIRECTORIES=$work
ORIGINAL="$REF/plugin-flutter"
# The files the scaffolding owns; every other tracked file of the original is its content.
OWNED=".claude-plugin/plugin.json .claude-plugin/marketplace.json LICENSE .gitignore tests/lib.sh tests/run-all.sh"

run_pp() {
  PP_OUTPUT=$("$BASH" "$PP" "$@" 2>&1)
  PP_STATUS=$?
}
state() {
  printf '%s|%s|%s' "$(git -C "$1" rev-parse HEAD)" "$(git -C "$1" status --porcelain)" \
    "$(cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
}

echo "# refus, sans rien écrire"
mkdir -p "$work/occupied" && echo x >"$work/occupied/note"
run_pp rebuild "$ORIGINAL" "$work/occupied"
[[ $PP_STATUS == 1 && $(ls "$work/occupied") == note ]] && grep -q 'refusé' <<<"$PP_OUTPUT" \
  && pass "dossier cible non vide : refusé, rien n'y est écrit" || fail "dossier cible non vide : refusé, rien n'y est écrit" "exit $PP_STATUS ; $PP_OUTPUT"
mkdir -p "$work/not-git/.claude-plugin" && echo '{}' >"$work/not-git/.claude-plugin/plugin.json"
run_pp rebuild "$work/not-git" "$work/r1"
[[ $PP_STATUS == 1 && ! -e $work/r1 ]] && grep -q 'dépôt git' <<<"$PP_OUTPUT" \
  && pass "original hors d'un dépôt git : refusé" || fail "original hors d'un dépôt git : refusé" "exit $PP_STATUS ; $PP_OUTPUT"
run_pp rebuild "$work" "$work/r2"
[[ $PP_STATUS == 1 && ! -e $work/r2 ]] && grep -q 'plugin.json' <<<"$PP_OUTPUT" \
  && pass "original sans plugin.json : refusé" || fail "original sans plugin.json : refusé" "exit $PP_STATUS ; $PP_OUTPUT"

echo "# reconstruction"
before=$(state "$ORIGINAL")
dest="$work/rebuild/plugin-flutter"
run_pp rebuild "$ORIGINAL" "$dest"
[[ $PP_STATUS == 0 ]] && pass "rebuild : exit 0" || fail "rebuild : exit 0" "exit $PP_STATUS ; $(tail -n 25 <<<"$PP_OUTPUT" | tr '\n' '|')"
grep -q '^charpente : 0 écart' <<<"$PP_OUTPUT" && pass "aucun écart entre la charpente produite et l'originale" \
  || fail "aucun écart entre la charpente produite et l'originale" "$(sed -n '/^charpente/,/^suite/p' <<<"$PP_OUTPUT" | tr '\n' '|' | head -c 900)"
grep -q '^suite de la reconstruction : exit 0' <<<"$PP_OUTPUT" && pass "rebuild rapporte la suite verte" \
  || fail "rebuild rapporte la suite verte" "$(grep '^suite' <<<"$PP_OUTPUT")"
[[ $(state "$ORIGINAL") == "$before" ]] && pass "original intact : HEAD, git status et empreintes identiques" \
  || fail "original intact : HEAD, git status et empreintes identiques"

echo "# contenu importé tel quel"
differs=""
while IFS= read -r file; do
  [[ " $OWNED " == *" $file "* ]] && continue
  cmp -s <(git -C "$ORIGINAL" show "HEAD:$file") "$dest/$file" || differs+="$file "
done < <(git -C "$ORIGINAL" ls-files)
[[ -z $differs ]] && pass "chaque fichier du contenu est identique à celui de l'original" \
  || fail "chaque fichier du contenu est identique à celui de l'original" "$differs"

echo "# charpente produite"
for file in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  [[ $(jq -S . "$dest/$file" 2>/dev/null) == "$(git -C "$ORIGINAL" show "HEAD:$file" | jq -S .)" ]] \
    && pass "$file : le même que l'original" || fail "$file : le même que l'original" "$(jq -c . "$dest/$file" 2>&1)"
done
cmp -s <(git -C "$ORIGINAL" show HEAD:LICENSE) "$dest/LICENSE" && pass "LICENSE : la même que l'original" || fail "LICENSE : la même que l'original"
missing=$(git -C "$ORIGINAL" show HEAD:.gitignore | grep -v '^#' | grep . | grep -vxFf "$dest/.gitignore")
[[ -f $dest/.gitignore && -z $missing ]] && pass ".gitignore : toutes les lignes de l'original" || fail ".gitignore : toutes les lignes de l'original" "$missing"
for helper in restricted_path bash_input SCRIPTS; do
  (source "$dest/tests/lib.sh" >/dev/null 2>&1 && { declare -F "$helper" >/dev/null || [[ -v $helper ]]; }) \
    && pass "tests/lib.sh définit $helper, dont se servent les tests de l'original" \
    || fail "tests/lib.sh définit $helper, dont se servent les tests de l'original"
done

for file in tests/lib.sh tests/run-all.sh; do
  cmp -s "$PLUGIN_ROOT/$file" "$dest/$file" && pass "$file : celui de plugin-plugin, jamais celui de l'original" \
    || fail "$file : celui de plugin-plugin, jamais celui de l'original"
done

echo "# sa propre suite et la validation stricte"
suite_output=$(cd "$work" && bash "$dest/tests/run-all.sh" 2>&1)
suite_status=$?
[[ $suite_status == 0 ]] && pass "bash tests/run-all.sh de la reconstruction : exit 0" \
  || fail "bash tests/run-all.sh de la reconstruction : exit 0" "$(sed -n '/== bilan/,$p' <<<"$suite_output" | tr '\n' '|')"
not_run=""
while IFS= read -r file; do
  grep -qxF "== $file" <<<"$suite_output" || not_run+="$file "
done < <(git -C "$ORIGINAL" ls-files 'tests/static/test_*.sh' 'tests/hooks/test_*.sh')
[[ -z $not_run ]] && pass "chaque test de l'original est lancé" || fail "chaque test de l'original est lancé" "$not_run"
for target in . .claude-plugin/plugin.json skills agents; do
  grep -qE "^  ok +${target//./\\.}$" <<<"$suite_output" && pass "validation stricte : $target" || fail "validation stricte : $target"
done
run_pp check "$dest"
[[ $PP_STATUS == 0 ]] && pass "check : aucun écart au modèle" || fail "check : aucun écart au modèle" "$(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 400)"

echo "# un écart de charpente est rapporté"
# An original whose own test calls a helper plugin-plugin's harness lacks, and ignores a folder
# its scaffolding does not.
fixture="$work/plugin-fixe"
mkdir -p "$fixture/.claude-plugin" "$fixture/tests/static"
jq -n '{name: "plugin-fixe", version: "0.3.0", description: "Fixe.", author: {name: "Soon"},
  homepage: "https://github.com/soonlysoul/plugin-fixe", repository: "https://github.com/soonlysoul/plugin-fixe",
  license: "MIT"}' >"$fixture/.claude-plugin/plugin.json"
jq -n '{name: "plugin-fixe", description: "Local marketplace for the plugin-fixe Claude Code plugin.", owner: {name: "Soon"},
  plugins: [{name: "plugin-fixe", source: "./", description: "Fixe."}]}' >"$fixture/.claude-plugin/marketplace.json"
cp "$dest/LICENSE" "$fixture/LICENSE"
printf 'cache-local/\n' >"$fixture/.gitignore"
printf 'PASS=0 FAIL=0\npass() { PASS=$((PASS + 1)); }\nfail() { FAIL=$((FAIL + 1)); }\nhelper_maison() { :; }\nfinish() { [[ $FAIL == 0 ]]; }\n' >"$fixture/tests/lib.sh"
printf '#!/usr/bin/env bash\nsource "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"\nhelper_maison && pass ok || fail helper_maison\nfinish\n' >"$fixture/tests/static/test_maison.sh"
git -C "$fixture" init -q && git -C "$fixture" add -A \
  && git -C "$fixture" -c user.name=t -c user.email=t@example.invalid commit -qm init
echo x >"$fixture/brouillon.txt"
run_pp rebuild "$fixture" "$work/rebuild/plugin-fixe"
grep -q "changements non enregistrés de l'original ignorés" <<<"$PP_OUTPUT" && [[ ! -e $work/rebuild/plugin-fixe/brouillon.txt ]] \
  && pass "changement non enregistré de l'original : signalé, pas reconstruit" \
  || fail "changement non enregistré de l'original : signalé, pas reconstruit" "$(head -n 3 <<<"$PP_OUTPUT" | tr '\n' '|')"
[[ $PP_STATUS == 1 ]] && pass "écart de charpente : exit 1" || fail "écart de charpente : exit 1" "exit $PP_STATUS"
for pattern in "^charpente : 2 écarts" "aide absente : helper_maison, dont se sert tests/static/test_maison.sh" \
  "ligne de l'original absente : cache-local/" "^  - tests/static/test_maison.sh$"; do
  grep -qE "$pattern" <<<"$PP_OUTPUT" && pass "rapporté : $pattern" || fail "rapporté : $pattern" "$(tr '\n' '|' <<<"$PP_OUTPUT" | head -c 600)"
done

finish
