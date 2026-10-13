#!/usr/bin/env bash
# Run the validator for a file's type.

[[ -n "${_FC_VALIDATE_LOADED:-}" ]] && return 0
_FC_VALIDATE_LOADED=1

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# fc_validate FILE TYPE — 0 valid, 1 invalid, 3 no validator available.
fc_validate() {
  local file="$1" type="$2"
  local validator="$FC_ROOT/validators/$type.sh"
  [[ -x "$validator" ]] || return 3
  local out rc=0
  out="$("$validator" "$file" 2>&1)" || rc=$?
  case "$rc" in
    0) return 0 ;;
    3) return 3 ;;
    *) [[ -n "$out" ]] && log_warn "validator: $out"; return 1 ;;
  esac
}
