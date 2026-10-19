#!/usr/bin/env bash
# Paths: every ${CLAUDE_PLUGIN_ROOT}/… cited by a skill or an agent exists; scripts under
# scripts/ and hooks/scripts/ are bash scripts that parse; no /bin/bash, no personal or store
# path anywhere in the components.
# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_paths
shopt -s nullglob

echo "# chemins cités"
substituted=("$PLUGIN_ROOT"/skills/*/SKILL.md "$PLUGIN_ROOT"/agents/*.md)
((${#substituted[@]} > 0)) && pass "skills et agents trouvés (${#substituted[@]})" || fail "skills et agents trouvés"
cited=$(cat "${substituted[@]}" /dev/null | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]*[A-Za-z0-9_/-]' | sort -u)
while IFS= read -r ref; do
  [[ -n $ref ]] || continue
  [[ -e $PLUGIN_ROOT/${ref#'${CLAUDE_PLUGIN_ROOT}/'} ]] && pass "chemin cité présent : $ref" || fail "chemin cité présent : $ref"
done <<<"$cited"

echo "# scripts"
scripts=("$PLUGIN_ROOT"/scripts/*.sh "$PLUGIN_ROOT"/scripts/lib/*.sh "$PLUGIN_ROOT"/hooks/scripts/*.sh "$PLUGIN_ROOT"/hooks/scripts/lib/*.sh)
for script in ${scripts[@]+"${scripts[@]}"}; do
  rel=${script#"$PLUGIN_ROOT"/}
  bash -n "$script" 2>/dev/null && pass "$rel : bash -n" || fail "$rel : bash -n"
  case $rel in
    */lib/*) ;;
    *) [[ $(head -n 1 "$script") == '#!/usr/bin/env bash' ]] && pass "$rel : #!/usr/bin/env bash" \
      || fail "$rel : #!/usr/bin/env bash" "$(head -n 1 "$script")" ;;
  esac
done
for script in "$PLUGIN_ROOT"/scripts/*.sh "$PLUGIN_ROOT"/hooks/scripts/*.sh; do
  name=${script##*/}
  grep -qF "\${CLAUDE_PLUGIN_ROOT}/${script#"$PLUGIN_ROOT"/}" "${substituted[@]}" "$PLUGIN_ROOT"/hooks/hooks.json /dev/null \
    && pass "$name est cité par \${CLAUDE_PLUGIN_ROOT}" || fail "$name est cité par \${CLAUDE_PLUGIN_ROOT}"
done

# The fact base describes these paths, it does not use them: scripts/facts/ is left out.
components=()
for dir in agents skills hooks scripts templates; do [[ -d $PLUGIN_ROOT/$dir ]] && components+=("$PLUGIN_ROOT/$dir"); done
bin_bash=$(grep -rn --exclude-dir=facts '/bin/bash' ${components[@]+"${components[@]}"} /dev/null 2>/dev/null)
[[ -z $bin_bash ]] && pass "aucun /bin/bash (absent sous NixOS)" || fail "aucun /bin/bash (absent sous NixOS)" "$bin_bash"
personal=$(grep -rnE --exclude-dir=facts '/home/|/Users/|/nix/store/' ${components[@]+"${components[@]}"} /dev/null 2>/dev/null)
[[ -z $personal ]] && pass "aucun chemin personnel ni du store" || fail "aucun chemin personnel ni du store" "$personal"
shopt -u nullglob

finish
