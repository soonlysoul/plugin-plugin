# shellcheck shell=bash
# Shared by scripts/pp.sh and hooks/scripts/doc-status-guard.sh: the status line of a framing
# document, and the fingerprint of its body that an approval records in
# .plugin-plugin/approvals.log (date, document, fingerprint, quote; tab-separated).

# doc_status <file>: BROUILLON, REVUE or APPROUVÉ; empty when the file has no status line.
doc_status() {
  grep -m 1 -oE '^\*\*Statut : (BROUILLON|REVUE|APPROUVÉ)\*\*' "$1" 2>/dev/null | sed -E 's/^\*\*Statut : (.*)\*\*$/\1/'
}

# doc_fingerprint <file>: sha256 of the document without its status line.
doc_fingerprint() {
  awk '!done && /^\*\*Statut : (BROUILLON|REVUE|APPROUVÉ)\*\*/ { done = 1; next } { print }' "$1" |
    sha256sum | cut -d' ' -f1
}

# doc_set_status <file> <status line>: replaces the status line, and nothing else.
doc_set_status() {
  local tmp
  tmp=$(mktemp) || return 1
  if STATUS_LINE=$2 awk '!done && /^\*\*Statut : (BROUILLON|REVUE|APPROUVÉ)\*\*/ { print ENVIRON["STATUS_LINE"]; done = 1; next } { print }' \
    "$1" >"$tmp"; then
    cat "$tmp" >"$1"
  fi
  rm -f "$tmp"
}

# approved_fingerprint <project root> <docs/NAME.md>: the fingerprint of the last approval.
approved_fingerprint() {
  awk -F'\t' -v doc="$2" '$2 == doc { fingerprint = $3 } END { print fingerprint }' \
    "$1/.plugin-plugin/approvals.log" 2>/dev/null
}
