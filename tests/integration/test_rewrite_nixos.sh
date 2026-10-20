#!/usr/bin/env bash
# The rewrite of plugin-nixos at the model (phase 14, criterion 2), from its read copy in build/ref/
# (PP_REF_DIR elsewhere): pp.sh rebuild alone leaves it off the model; tests/rewrite/plugin-nixos.sh
# ports it, its ported suite exits 0, pp.sh check finds no gap, every case of the original suite
# keeps its equivalent, and the copy never changes. Skipped without the copy.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_rewrite_nixos
REF=${PP_REF_DIR:-$PLUGIN_ROOT/build/ref}
ORIGINAL="$REF/plugin-nixos"

if [[ ! -d $ORIGINAL/.git ]]; then
  skip "réécriture de plugin-nixos" "copie de lecture absente de $ORIGINAL"
  finish
  exit
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GIT_CEILING_DIRECTORIES=$work

state() {
  printf '%s|%s|%s' "$(git -C "$1" rev-parse HEAD)" "$(GIT_OPTIONAL_LOCKS=0 git -C "$1" status --porcelain)" \
    "$(cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
}
expect_line() {
  if grep -qE -- "$2" <<<"$OUTPUT"; then pass "$1"; else fail "$1" "motif absent : $2"; fi
}
before=$(state "$ORIGINAL")

echo "# pp.sh rebuild seul : hors modèle"
"$BASH" "$PLUGIN_ROOT/scripts/pp.sh" rebuild "$ORIGINAL" "$work/rebuilt" >/dev/null 2>&1
OUTPUT=$("$BASH" "$PLUGIN_ROOT/scripts/pp.sh" check "$work/rebuilt" 2>&1)
status=$?
[[ $status == 1 ]] && pass "reconstruit sans portage : check sort en 1" || fail "reconstruit sans portage : check sort en 1" "exit $status"
for gap in '\[forme des hooks\] PreToolUse \[Bash\|Monitor\] garde-nixos\.sh' '\[arborescence des hooks\] hooks/garde-nixos\.sh' \
  '\[arborescence\] hors modèle : modeles' '\[harnais\] tests/test_garde\.sh'; do
  expect_line "écart de la liste de travail : $gap" "$gap"
done

echo "# la réécriture"
OUTPUT=$("$BASH" "$PLUGIN_ROOT/tests/rewrite/plugin-nixos.sh" "$ORIGINAL" "$work/rewrite/plugin-nixos" 2>&1)
status=$?
[[ $status == 0 ]] && pass "réécriture : exit 0" || fail "réécriture : exit 0" "exit $status ; $(tail -n 25 <<<"$OUTPUT" | tr '\n' '|')"
expect_line "suite portée : exit 0" '^suite portée : exit 0$'
expect_line "suite portée : zéro échec" '^échouées : 0$'
expect_line "coût au-delà du seuil : une alerte, pas un échec" '^  - coût en contexte \([0-9]+ tokens > 1000\)$'
for target in . .claude-plugin/plugin.json skills; do
  expect_line "validation stricte : $target" "^  ok +${target//./\\.}$"
done
expect_line "check : aucun écart" '^écarts : 0 — au modèle de plugin-flutter$'
for suite in garde nixconf statique; do
  expect_line "test_$suite : chacun de ses cas a son équivalent" "^\| tests/test_$suite\.sh \| ([0-9]+) réussis, 0 échoués, 0 sautés \| tests/(hooks|static)/[a-z_]+\.sh \| [0-9]+ réussis, 0 échoués, [0-9]+ sautés \| 0 \|$"
done
expect_line "cas d'origine sans équivalent : 0" "^cas d'origine sans équivalent : 0$"
expect_line "la réécriture prouve l'original intact" '^original intact : HEAD, git status et empreintes identiques$'

echo "# ce que le modèle impose, et rien d'autre"
dest="$work/rewrite/plugin-nixos"
jq -e '.hooks.PreToolUse[0].hooks[0] == {type: "command", command: "bash",
  args: ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/garde-nixos.sh"], timeout: 15, onFailure: "block"}' "$dest/hooks/hooks.json" >/dev/null 2>&1 \
  && pass "hooks.json : forme exec, onFailure block, timeout d'origine" || fail "hooks.json : forme exec, onFailure block, timeout d'origine" "$(jq -c . "$dest/hooks/hooks.json" 2>&1)"
cmp -s <(git -C "$ORIGINAL" show HEAD:hooks/lib-commande.sh) "$dest/hooks/scripts/lib/lib-commande.sh" \
  && pass "lib-commande.sh déplacé, identique" || fail "lib-commande.sh déplacé, identique"
changed=$(diff <(git -C "$ORIGINAL" show HEAD:hooks/garde-nixos.sh) "$dest/hooks/scripts/garde-nixos.sh" | grep '^[<>]')
[[ -n $changed && -z $(grep -vE 'lib-commande\.sh|verifier_cmd=|Fail-closed|onFailure' <<<"$changed") ]] \
  && pass "garde-nixos.sh : le chemin de sa bibliothèque et de nixconf, et son mode déclaré, rien d'autre" \
  || fail "garde-nixos.sh : le chemin de sa bibliothèque et de nixconf, et son mode déclaré, rien d'autre" "$(tr '\n' '|' <<<"$changed")"
differs=""
for file in $(git -C "$ORIGINAL" ls-files skills scripts/mcp-nixos.sh LICENSE); do
  cmp -s <(git -C "$ORIGINAL" show "HEAD:$file") "$dest/$file" || differs+="$file "
done
[[ -z $differs ]] && pass "skills, lanceur MCP, LICENSE : identiques à l'original" \
  || fail "skills, lanceur MCP, LICENSE : identiques à l'original" "$differs"
echo "# le serveur MCP, déclaré comme en phase 9"
[[ $(jq -cS . "$dest/.mcp.json" 2>/dev/null) == "$(git -C "$ORIGINAL" show HEAD:.mcp.json | jq -cS .)" ]] \
  && pass ".mcp.json : la déclaration de pp.sh add-mcp, celle de l'original" || fail ".mcp.json : la déclaration de pp.sh add-mcp, celle de l'original"
expect_line "test du serveur, écrit par add-mcp, vert" '^test_mcp_nixos : [0-9]+ réussis, 0 échoués'
expect_line "rappel de la doublure d'évaluation" "^  rappel : un skill qui dépend du serveur nixos a besoin d'une doublure dans evals/mocks/nixos/"
cmp -s <(git -C "$ORIGINAL" show HEAD:README.md) <(awk '/^## Serveurs MCP$/ { skip = 1; next } skip && /^## / { skip = 0 } !skip' "$dest/README.md") \
  && grep -qF '`evals/mocks/nixos/`' "$dest/README.md" \
  && pass "README : l'original, plus la section « Serveurs MCP » de add-mcp" || fail "README : l'original, plus la section « Serveurs MCP » de add-mcp"
[[ $(state "$ORIGINAL") == "$before" ]] && pass "copie de lecture intacte : HEAD, git status et empreintes identiques" \
  || fail "copie de lecture intacte : HEAD, git status et empreintes identiques"

finish
