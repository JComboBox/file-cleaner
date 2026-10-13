#!/usr/bin/env bash
# Walk a repository's tracked files and clean each supported file.
#
# Usage: scripts/fc-clean.sh REPO_DIR
#
# Writes one status line per file (see fc-clean-file.sh) to stdout and a
# summary to stderr. Exit status: 0 on success, 1 if any file errored.
set -euo pipefail
# shellcheck source=lib/git.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git.sh"
load_config

(( $# == 1 )) || { echo "usage: $0 REPO_DIR" >&2; exit 64; }
require_repo_dir "$1"
repo="$(cd "$1" && pwd)"

# Build a grep filter for excluded top-level or nested directories.
exclude_re=""
for d in $FC_EXCLUDE_DIRS; do
  exclude_re+="${exclude_re:+|}(^|/)${d//./\\.}/"
done

declare -A counts=()
errors=0
while IFS= read -r -d '' rel; do
  if [[ -n "$exclude_re" ]] && grep -Eq "$exclude_re" <<<"$rel"; then
    continue
  fi
  line="$(cd "$repo" && "$FC_ROOT/scripts/fc-clean-file.sh" "$rel")"
  status="${line%%$'\t'*}"
  counts[$status]=$(( ${counts[$status]:-0} + 1 ))
  [[ "$status" == error ]] && errors=$((errors + 1))
  [[ "$status" != skipped && "$status" != unchanged ]] && printf '%s\n' "$line"
  [[ "$status" == unchanged ]] && log_debug "$line"
done < <(git -C "$repo" ls-files -z)

summary=""
for s in changed unvalidated reverted unchanged skipped error; do
  summary+="$s=${counts[$s]:-0} "
done
log_info "summary: $summary"
(( errors == 0 ))
