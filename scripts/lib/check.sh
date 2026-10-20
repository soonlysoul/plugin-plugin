# shellcheck shell=bash
# The gaps of a plugin to the model, plugin-flutter, for pp.sh check: one line per broken rule,
# « [catégorie] détail », nothing when the plugin follows the model. It reads, it never writes.
# Structure only: the house style of the components plugin-plugin adds (tests/headers.sh) and the
# language of a plugin are its own choices. Relies on name_error and OWNER (pp.sh), tests/headers.sh
# and tests/mcp.sh.

# What a plugin of the model keeps at its root; hidden entries (.claude-plugin, .mcp.json, .git…)
# are checked one by one, not listed here.
MODEL_TOP=" skills agents hooks scripts templates tests docs evals LICENSE README.md CHANGELOG.md PROGRESS.md ARCHITECTURE.md "
MODEL_DOCS="INSTALLATION USER_GUIDE SECURITY TROUBLESHOOTING"
PLUGIN_JSON_KEYS='["name", "version", "description", "author", "license", "keywords", "homepage", "repository"]'
SEMVER='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
# Files that do not belong in a plugin (plugin-validator).
PARASITES='(^|/)(node_modules|\.DS_Store|Thumbs\.db)(/|$)|\.swp$'
# Credentials written in clear: a private key, GitHub, Anthropic, OpenAI, AWS and Slack tokens.
SECRETS='-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,}|sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}'

# visible_files <dir>: the files a clone would carry, one relative path per line — tracked and
# untracked, never what .gitignore ignores; every file but .git/ outside of a repository, or in a
# folder the enclosing repository ignores (a copy under build/).
visible_files() {
  local file top here
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)
  here=$(cd "$1" && pwd -P)
  if [[ -n $top ]] && { [[ $here == "$top" ]] || ! git -C "$top" check-ignore -q -- "${here#"$top"/}" 2>/dev/null; }; then
    while IFS= read -r file; do
      [[ -f $1/$file ]] && printf '%s\n' "$file"
    done < <(git -C "$1" -c core.quotepath=off ls-files -co --exclude-standard)
  else
    (cd "$1" && find . -path ./.git -prune -o -type f -print | sed 's#^\./##')
  fi
}

gaps_manifest() {
  local d=$1 pj="$1/.claude-plugin/plugin.json" mj="$1/.claude-plugin/marketplace.json" name error repo value
  if ! jq -e 'type == "object"' "$pj" >/dev/null 2>&1; then
    echo "[manifeste] .claude-plugin/plugin.json illisible"
    return
  fi
  name=$(jq -r '.name // "" | tostring' "$pj")
  error=$(name_error "$name")
  [[ -z $error ]] || echo "[manifeste] nom hors format : ${error#refusé : }"
  value=$(jq -r '.version // "" | tostring' "$pj")
  [[ $value =~ $SEMVER ]] || echo "[manifeste] version « $value » hors SemVer"
  jq -e '.description | type == "string" and length > 0' "$pj" >/dev/null || echo "[manifeste] description absente"
  if ! jq -e '.author == {name: "Soon"}' "$pj" >/dev/null; then
    echo "[manifeste] author : {\"name\": \"Soon\"} attendu, sans e-mail ; trouvé les champs $(jq -c '.author | if type == "object" then keys else type end' "$pj")"
  elif grep -q '@' "$pj"; then
    echo "[manifeste] adresse e-mail dans plugin.json"
  fi
  value=$(jq -r '.license // "" | tostring' "$pj")
  [[ $value == MIT ]] || echo "[manifeste] license « $value », MIT attendu"
  repo="https://github.com/$OWNER/$name"
  for value in homepage repository; do
    jq -e --arg k "$value" --arg r "$repo" '.[$k] == $r' "$pj" >/dev/null \
      || echo "[manifeste] $value « $(jq -r --arg k "$value" '.[$k] // "" | tostring' "$pj") », le dépôt dédié $repo attendu"
  done
  value=$(jq -r --argjson known "$PLUGIN_JSON_KEYS" 'keys - $known | join(", ")' "$pj")
  [[ -z $value ]] || echo "[manifeste] champ inconnu dans plugin.json : $value"

  if [[ ! -f $mj ]]; then
    echo "[manifeste] .claude-plugin/marketplace.json absent : la marketplace locale, une entrée « source : ./ »"
  elif ! jq -e '.plugins | type == "array"' "$mj" >/dev/null 2>&1; then
    echo "[manifeste] marketplace.json illisible, sans liste « plugins »"
  else
    jq -e '.owner.name == "Soon"' "$mj" >/dev/null || echo "[manifeste] marketplace.json : owner.name n'est pas Soon"
    jq -e '.plugins | length == 1' "$mj" >/dev/null || echo "[manifeste] marketplace.json : une seule entrée attendue"
    jq -e '.plugins[0].source == "./"' "$mj" >/dev/null || echo "[manifeste] marketplace.json : source de l'entrée autre que « ./ »"
    jq -e '.plugins[0] | has("version") | not' "$mj" >/dev/null || echo "[manifeste] marketplace.json : l'entrée répète la version, que seul plugin.json porte"
    jq -e --arg n "$name" '.plugins[0].name == $n' "$mj" >/dev/null || echo "[manifeste] marketplace.json : le nom de l'entrée n'est pas « $name »"
  fi
}

gaps_root() {
  local d=$1 files=$2 version entry doc
  { [[ -f $d/LICENSE ]] && grep -q '^MIT License' "$d/LICENSE" && grep -q 'Copyright (c) [0-9]* Soon$' "$d/LICENSE"; } \
    || echo "[racine] LICENSE MIT au nom de Soon absente"
  [[ -s $d/README.md ]] || echo "[racine] README.md absent"
  version=$(jq -r '.version // "" | tostring' "$d/.claude-plugin/plugin.json" 2>/dev/null)
  if [[ ! -f $d/CHANGELOG.md ]]; then echo "[racine] CHANGELOG.md absent"
  elif ! grep -qF "## [$version]" "$d/CHANGELOG.md"; then echo "[racine] CHANGELOG.md sans entrée pour la version $version de plugin.json"
  fi
  [[ -f $d/PROGRESS.md ]] || echo "[racine] PROGRESS.md absent"
  [[ -f $d/ARCHITECTURE.md || -f $d/docs/ARCHITECTURE.md ]] || echo "[racine] ARCHITECTURE.md absent (à la racine ou dans docs/)"
  for doc in $MODEL_DOCS; do
    [[ -f $d/docs/$doc.md ]] || echo "[racine] docs/$doc.md absent"
  done
  [[ -f $d/.gitignore ]] || echo "[racine] .gitignore absent"
  [[ ! -e $d/CLAUDE.md ]] || echo "[racine] CLAUDE.md à la racine : un plugin ne le charge pas"
  while IFS= read -r entry; do
    [[ -z $entry || $entry == .* || $MODEL_TOP == *" $entry "* ]] \
      || echo "[arborescence] hors modèle : $entry — à la racine, les composants (skills, agents, hooks, scripts, templates), tests, docs, evals et les fichiers du modèle"
  done < <(cut -d/ -f1 <<<"$files" | sort -u)
}

gaps_hooks() {
  local d=$1 files=$2 hooks_json="$1/hooks/hooks.json" file hooks event matcher type command arg0 on_failure argc timeout label ref script
  while IFS= read -r file; do
    case $file in
      hooks/hooks.json | hooks/agent-scope.json | hooks/scripts/*) ;;
      hooks/*) echo "[arborescence des hooks] $file hors de hooks/scripts/ : hooks/ ne contient que hooks.json et scripts/" ;;
    esac
  done <<<"$files"
  if [[ ! -e $hooks_json ]]; then
    [[ $(grep -c '^hooks/scripts/[^/]*\.sh$' <<<"$files") == 0 ]] || echo "[hooks] scripts sous hooks/scripts/ sans hooks/hooks.json"
    return
  fi
  if ! jq -e '.hooks | type == "object"' "$hooks_json" >/dev/null 2>&1; then
    echo "[hooks] hooks/hooks.json illisible, sans enveloppe « hooks »"
    return
  fi
  # One line per hook. Fields are joined by \x1f: read merges consecutive tabs.
  hooks=$(jq -r '.hooks | to_entries[] | .key as $event | .value[] | (.matcher // "") as $m
                 | .hooks[] | [$event, $m, (.type // ""), (.command // ""), (.args[0] // ""),
                               (.onFailure // ""), ((.args // []) | length), (.timeout // "")]
                 | map(tostring) | join("\u001f")' "$hooks_json")
  while IFS=$'\x1f' read -r event matcher type command arg0 on_failure argc timeout; do
    [[ -n $event ]] || continue
    ref=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+|[A-Za-z0-9_./-]+\.sh' <<<"$arg0 $command" | head -n 1)
    label="$event${matcher:+ [$matcher]} ${ref##*/}"
    if [[ $type != command ]]; then
      echo "[hooks] $label : type « $type », command attendu"
      continue
    fi
    [[ $command == bash && $argc == 1 ]] \
      || echo "[forme des hooks] $label : forme exec attendue, command « bash » et le script seul dans args ; trouvé command « $command »"
    [[ $timeout =~ ^[0-9]+$ ]] || echo "[hooks] $label : timeout non déclaré"
    [[ $event == Stop || $event == SubagentStop || $on_failure == block || $on_failure == continue ]] \
      || echo "[hooks] $label : onFailure non déclaré, block en fail-closed, continue en fail-open"
    [[ $command == bash && $argc == 1 ]] || continue
    if [[ $arg0 != '${CLAUDE_PLUGIN_ROOT}/'* ]]; then
      echo "[hooks] $label : chemin sans \${CLAUDE_PLUGIN_ROOT} : $arg0"
      continue
    fi
    script=$d/${arg0#'${CLAUDE_PLUGIN_ROOT}/'}
    if [[ ! -f $script ]]; then
      echo "[hooks] $label : script absent : $arg0"
    elif grep -q '^# Fail-closed' "$script" && [[ $on_failure != block ]]; then
      echo "[hooks] $label : déclaré fail-closed, onFailure « $on_failure » ; block attendu"
    elif grep -q '^# Fail-open' "$script" && [[ $event != Stop && $event != SubagentStop && $on_failure != continue ]]; then
      echo "[hooks] $label : déclaré fail-open, onFailure « $on_failure » ; continue attendu"
    fi
  done <<<"$hooks"
  while IFS= read -r file; do
    [[ $file =~ ^hooks/scripts/[^/]+\.sh$ ]] || continue
    grep -qF "$file" "$hooks_json" || echo "[hooks] non câblé dans hooks.json : $file"
  done <<<"$files"
}

gaps_scripts() {
  local d=$1 files=$2 file
  while IFS= read -r file; do
    [[ $file =~ ^(hooks/)?scripts/([^/]+|lib/[^/]+)\.sh$ ]] || continue
    bash -n "$d/$file" 2>/dev/null || echo "[scripts] $file : bash -n échoue"
    [[ $file == */lib/* || $(head -n 1 "$d/$file") == '#!/usr/bin/env bash' ]] \
      || echo "[scripts] $file : première ligne « $(head -n 1 "$d/$file") », #!/usr/bin/env bash attendu"
  done <<<"$files"
}

# A writing or shell agent needs a scope guard: a PreToolUse hook script that reads agent_type.
scope_guarded() {
  local d=$1 arg0
  while IFS= read -r arg0; do
    grep -q 'agent_type' "$d/${arg0#'${CLAUDE_PLUGIN_ROOT}/'}" 2>/dev/null && return 0
  done < <(jq -r '.hooks.PreToolUse[]?.hooks[]? | .args[0]? // empty' "$d/hooks/hooks.json" 2>/dev/null)
  return 1
}

gaps_components() {
  local d=$1 files=$2 file error dir tools line
  local -a cited_from=()
  shopt -s nullglob
  for dir in "$d"/skills/*/; do
    [[ -f $dir/SKILL.md ]] || echo "[skills] ${dir#"$d"/} sans SKILL.md"
  done
  for file in "$d"/skills/*/SKILL.md; do
    cited_from+=("$file")
    while IFS= read -r error; do
      [[ -z $error ]] || echo "[skills] ${file#"$d"/} : $error"
    done < <(skill_structure_errors "$file")
  done
  for file in "$d"/agents/*.md; do
    cited_from+=("$file")
    while IFS= read -r error; do
      [[ -z $error ]] || echo "[agents] ${file#"$d"/} : $error"
    done < <(agent_structure_errors "$file")
    if read_frontmatter "$file" 2>/dev/null; then
      tools=${FM[tools]-}
      if [[ ,${tools// /}, =~ ,(Write|Edit|NotebookEdit|Bash), ]] && ! scope_guarded "$d"; then
        echo "[agents] ${file#"$d"/} : outils « $tools » sans garde de portée, un hook PreToolUse qui lit agent_type"
      fi
    fi
  done
  shopt -u nullglob
  [[ ! -f $d/.mcp.json ]] || cited_from+=("$d/.mcp.json")

  while IFS= read -r file; do
    [[ -z $file || -e $d/${file#'${CLAUDE_PLUGIN_ROOT}/'} ]] || echo "[chemins] chemin cité absent : $file"
  done < <(cat "${cited_from[@]}" /dev/null | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]*[A-Za-z0-9_/-]' | sort -u)
  while IFS= read -r file; do
    [[ $file =~ ^(templates/|skills/[^/]+/.) && $file != */SKILL.md ]] || continue
    grep -qF "\${CLAUDE_PLUGIN_ROOT}/$file" "${cited_from[@]}" /dev/null || echo "[chemins] $file n'est cité par aucun \${CLAUDE_PLUGIN_ROOT}/…"
  done <<<"$files"
  local component='^(agents|skills|hooks|scripts|templates)/|^\.mcp\.json$'
  while IFS= read -r file; do
    [[ $file =~ $component && $file != scripts/facts/* ]] || continue
    grep -qI . "$d/$file" 2>/dev/null || continue
    # Bracketed letters keep these patterns from matching this very file.
    line=$(grep -n '/bin/[b]ash' "$d/$file" | head -n 1 | cut -d: -f1)
    [[ -z $line ]] || printf '[chemins] interpréteur à chemin fixe, absent sous NixOS (#!/usr/bin/env bash attendu) : %s:%s\n' "$file" "$line"
    line=$(grep -nE '/(home|Users)/[A-Za-z0-9_.-]+/|/nix/[s]tore/[a-z0-9]{32}-' "$d/$file" | head -n 1 | cut -d: -f1)
    [[ -z $line ]] || printf '[chemins] chemin personnel ou du store : %s:%s\n' "$file" "$line"
  done <<<"$files"

  [[ -f $d/.mcp.json ]] || return 0
  if ! jq -e '.mcpServers | type == "object"' "$d/.mcp.json" >/dev/null 2>&1; then
    echo "[MCP] .mcp.json illisible, sans enveloppe « mcpServers »"
    return
  fi
  local server entry
  while IFS= read -r server; do
    entry=$(jq -c --arg s "$server" '.mcpServers[$s]' "$d/.mcp.json")
    if jq -e 'has("command")' <<<"$entry" >/dev/null; then error=$(mcp_launcher_error "$entry"); else error=$(mcp_remote_error "$entry"); fi
    for error in "$error" "$(mcp_install_error "$entry" "$d")" "$(mcp_variable_error "$entry")" "$(mcp_secret_error "$entry")"; do
      [[ -z $error ]] || echo "[MCP] serveur $server : $error"
    done
  done < <(jq -r '.mcpServers | keys_unsorted[]' "$d/.mcp.json")
}

gaps_harness() {
  local d=$1 files=$2 file test
  [[ -f $d/tests/run-all.sh ]] || echo "[harnais] tests/run-all.sh absent : la suite déterministe, sortie 0, 1 ou 2"
  [[ -f $d/tests/lib.sh ]] || echo "[harnais] tests/lib.sh absent : les aides partagées des tests"
  grep -qE '^tests/static/test_[^/]+\.sh$' <<<"$files" || echo "[harnais] tests/static/ sans test"
  while IFS= read -r file; do
    [[ $file =~ ^tests/test_[^/]+\.sh$ ]] && echo "[harnais] $file hors de tests/static/ et tests/hooks/"
  done <<<"$files"
  while IFS= read -r file; do
    [[ $file =~ ^hooks/scripts/([^/]+)\.sh$ ]] || continue
    test="tests/hooks/test_${BASH_REMATCH[1]//-/_}.sh"
    [[ -f $d/$test ]] || echo "[harnais] $file sans son test sur entrées simulées, $test"
  done <<<"$files"
}

# placeholder <match>: a documented example (…EXAMPLE) or a filler that repeats one character.
placeholder() {
  local tail=${1: -16}
  [[ $1 == *EXAMPLE* || -z ${tail//"${tail:0:1}"/} ]]
}

gaps_hygiene() {
  local d=$1 files=$2 file
  grep -E "$PARASITES" <<<"$files" | sed -E 's#^((.*/)?node_modules)/.*#\1/#' | sort -u | sed 's#^#[hygiène] fichier parasite : #'
  while IFS= read -r file; do
    [[ -n $file ]] || continue
    # The line number only: the credential itself is never copied.
    grep -noIE -- "$SECRETS" "$d/$file" 2>/dev/null | while IFS=: read -r line match; do
      placeholder "$match" || printf '[hygiène] identifiant en clair : %s:%s\n' "$file" "$line"
    done | sort -u
  done <<<"$files"
}

# check_gaps <dir>: every gap of the plugin to the model.
check_gaps() {
  local files
  files=$(visible_files "$1")
  gaps_manifest "$1"
  gaps_root "$1" "$files"
  gaps_hooks "$1" "$files"
  gaps_scripts "$1" "$files"
  gaps_components "$1" "$files"
  gaps_harness "$1" "$files"
  gaps_hygiene "$1" "$files"
}
