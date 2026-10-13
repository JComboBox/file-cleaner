#!/usr/bin/env bash
# Clean one file, validate it, and revert if validation fails.
#
# Usage: scripts/fc-clean-file.sh [-t TYPE] FILE
#
# Prints one tab-separated status line to stdout:
#   STATUS<TAB>TYPE<TAB>FILE
# where STATUS is changed | unchanged | reverted | unvalidated | skipped | error.
#   unvalidated: changed, but no validator was available (kept unless
#                FC_REQUIRE_VALIDATOR=1, in which case it is reverted).
# Exit status is 0 unless the script itself was misused.
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=lib/filetypes.sh
source "$FC_ROOT/lib/filetypes.sh"
# shellcheck source=lib/validate.sh
source "$FC_ROOT/lib/validate.sh"
load_config

type=""
while getopts "t:h" opt; do
  case "$opt" in
    t) type="$OPTARG" ;;
    h) sed -n '2,12p' "$0"; exit 0 ;;
    *) exit 64 ;;
  esac
done
shift $((OPTIND - 1))
(( $# == 1 )) || { echo "usage: $0 [-t TYPE] FILE" >&2; exit 64; }
file="$1"

report() { printf '%s\t%s\t%s\n' "$1" "${type:--}" "$file"; }

[[ -f "$file" && ! -L "$file" ]] || { report skipped; exit 0; }
[[ -n "$type" ]] || type="$(detect_type "$file")"
if [[ -z "$type" ]] || ! type_enabled "$type" || [[ ! -x "$FC_ROOT/cleaners/$type.sh" ]]; then
  report skipped; exit 0
fi

backup="$(mktemp)"
trap 'rm -f "$backup"' EXIT
cp -p "$file" "$backup"

restore() { cat "$backup" > "$file"; }

if ! "$FC_ROOT/cleaners/$type.sh" "$file"; then
  restore; log_warn "cleaner failed, restored: $file"; report error; exit 0
fi

if cmp -s "$file" "$backup"; then
  report unchanged; exit 0
fi

rc=0
fc_validate "$file" "$type" || rc=$?
case "$rc" in
  0) report changed ;;
  3)
    if is_true "$FC_REQUIRE_VALIDATOR"; then
      restore; log_warn "no validator for $type, reverted: $file"; report reverted
    else
      log_warn "no validator for $type, keeping change: $file"; report unvalidated
    fi
    ;;
  *) restore; log_warn "validation failed, reverted: $file"; report reverted ;;
esac
