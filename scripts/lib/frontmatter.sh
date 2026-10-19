# shellcheck shell=bash
# A deliberately strict reader of skill and agent frontmatter, after plugin-flutter's
# test_frontmatter.sh. A plugin agent whose frontmatter does not parse loads with every field
# ignored, hence with every tool and no message: the validator does not see it, this does.

# read_frontmatter <file>: fills FM (key -> value), or sets FM_ERROR and returns 1.
# Accepted: line 1 is ---, then single-line `key: value` lines, then ---. An unquoted value
# contains neither ": " nor " #" and does not start with a YAML indicator; a quoted value is
# enclosed in matching quotes. Keys are unique.
read_frontmatter() {
  local file=$1 line key value closed=0 n=0
  declare -gA FM=()
  FM_ERROR=""
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    if ((n == 1)); then
      [[ $line == --- ]] || { FM_ERROR="la ligne 1 n'est pas ---"; return 1; }
      continue
    fi
    if [[ $line == --- ]]; then closed=1; break; fi
    if [[ ! $line =~ ^([a-z][a-z0-9_-]*):\ (.+)$ ]]; then
      FM_ERROR="la ligne $n n'est pas un « clé: valeur » sur une ligne : $line"; return 1
    fi
    key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}
    [[ -z ${FM[$key]+set} ]] || { FM_ERROR="clé $key en double"; return 1; }
    case $value in
      \"*) [[ $value =~ ^\"[^\"]*\"$ ]] || { FM_ERROR="guillemets doubles déséquilibrés dans $key"; return 1; }; value=${value:1:-1} ;;
      \'*) [[ $value =~ ^\'[^\']*\'$ ]] || { FM_ERROR="guillemets simples déséquilibrés dans $key"; return 1; }; value=${value:1:-1} ;;
      [\[\]\{\}\&\*\!\|\>%@\`]*) FM_ERROR="$key commence par un indicateur YAML : $value"; return 1 ;;
      *': '* | *' #'*) FM_ERROR="$key non cité contient « : » ou « # » : $value"; return 1 ;;
    esac
    FM[$key]=$value
  done <"$file"
  ((closed)) || { FM_ERROR="l'en-tête n'est pas refermé par ---"; return 1; }
}

# body_of <file>: the Markdown after the frontmatter.
body_of() { awk 'n >= 2 { print } /^---$/ { n++ }' "$1"; }
