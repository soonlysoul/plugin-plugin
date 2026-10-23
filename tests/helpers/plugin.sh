# shellcheck shell=bash
# Helpers of plugin-plugin's own tests: a gh stub and a plugin created by pp.sh create in a
# temporary folder. Not copied into the plugins it creates.

# gh_stub <dir>: writes <dir>/gh. The marketplace soon lists plugin-alpha and plugin-beta;
# soonlysoul/plugin-taken-repo exists; every other repository is free (HTTP 404).
gh_stub() {
  mkdir -p "$1"
  cat >"$1/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STUB_GH_LOG:-/dev/null}"
case "$*" in
  "api repos/soonlysoul/claude-plugins/contents/.claude-plugin/marketplace.json"*)
    printf '%s' '{"name":"soon","owner":{"name":"Soon"},"plugins":[{"name":"plugin-alpha"},{"name":"plugin-beta"}]}' ;;
  "api repos/soonlysoul/plugin-taken-repo"*) echo '{"full_name":"soonlysoul/plugin-taken-repo"}' ;;
  "api repos/soonlysoul/"*) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  *) echo "gh stub: unexpected arguments: $*" >&2; exit 3 ;;
esac
STUB
  chmod +x "$1/gh"
}

# market_readme: a README of the marketplace soon in its form — a table of the plugins, the install
# commands, prose around them — from "name<TAB>description" lines on stdin, in order.
market_readme() {
  local -a names=() rows=()
  local name description
  while IFS=$'\t' read -r name description; do
    names+=("$name")
    rows+=("| \`$name\` | ${description//|/\\|} | [soonlysoul/$name](https://github.com/soonlysoul/$name) |")
  done
  printf '# Marketplace Claude Code `soon`\n\nLe catalogue des plugins Claude Code de Soon.\n\n'
  printf '| Plugin | Rôle | Dépôt |\n| --- | --- | --- |\n'
  printf '%s\n' "${rows[@]}"
  printf '\n## Installer sur un appareil\n\n```bash\nclaude plugin marketplace add soonlysoul/claude-plugins\n'
  for name in "${names[@]}"; do printf 'claude plugin install %s@soon --scope user\n' "$name"; done
  printf '```\n\n## Mettre à jour\n\n```bash\nclaude plugin marketplace update soon\nclaude plugin install plugin-alpha@soon --scope user\n```\n'
}

# new_plugin <parent dir> <name>: frames, approves and creates <parent>/<name> with pp.sh,
# through the gh stub. Prints the plugin's path; returns pp.sh create's exit code.
new_plugin() {
  local dir="$1/$2" pp="$PLUGIN_ROOT/scripts/pp.sh" doc
  mkdir -p "$dir/docs" "$1/.gh-stub"
  gh_stub "$1/.gh-stub"
  bash "$pp" init-state "$dir" >/dev/null
  for doc in PRD ARCHITECTURE; do
    printf '# %s — %s\n\n**Statut : BROUILLON**\n\nPlugin d essai.\n' "$doc" "$2" >"$dir/docs/$doc.md"
    bash "$pp" approve "$dir/docs/$doc.md" --quote "oui" >/dev/null
  done
  PATH="$1/.gh-stub:$PATH" bash "$pp" create "$dir" --name "$2" --description "Plugin d'essai." >/dev/null 2>&1
  local rc=$?
  printf '%s' "$dir"
  return "$rc"
}
