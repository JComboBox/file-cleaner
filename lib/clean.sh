#!/usr/bin/env bash
# Generic cleaning engine used by cleaners/<type>.sh.

[[ -n "${_FC_CLEAN_LOADED:-}" ]] && return 0
_FC_CLEAN_LOADED=1

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# fc_clean FILE TYPE [options] — rewrite FILE in place.
# Options describe the comment syntax of the language:
#   --line REGEX        line comment (e.g. '^[[:space:]]*#')
#   --block-start REGEX block comment opener
#   --block-end REGEX   block comment closer
#   --keep REGEX        leading lines to always preserve (shebang etc.)
# Patterns in rules/<TYPE>.patterns are applied automatically.
# Returns 0 whether or not anything changed; non-zero on error.
fc_clean() {
  local file="$1" type="$2"; shift 2
  local line="" bstart="" bend="" keep=""
  while (( $# )); do
    case "$1" in
      --line)        line="$2"; shift 2 ;;
      --block-start) bstart="$2"; shift 2 ;;
      --block-end)   bend="$2"; shift 2 ;;
      --keep)        keep="$2"; shift 2 ;;
      *) log_error "fc_clean: unknown option $1"; return 1 ;;
    esac
  done

  [[ -f "$file" ]] || { log_error "not a file: $file"; return 1; }

  local patterns="$FC_ROOT/rules/$type.patterns"
  [[ -f "$patterns" ]] || patterns=""

  local tmp
  tmp="$(mktemp)"
  if ! FC_AWK_LINE_COMMENT="$line" \
       FC_AWK_BLOCK_START="$bstart" \
       FC_AWK_BLOCK_END="$bend" \
       FC_AWK_KEEP="$keep" \
       FC_AWK_HEADER_PATTERN="${FC_HEADER_PATTERN,,}" \
       FC_AWK_SNIPPET_BEGIN="$FC_SNIPPET_BEGIN" \
       FC_AWK_SNIPPET_END="$FC_SNIPPET_END" \
       FC_AWK_PATTERN_FILE="$patterns" \
       awk -f "$FC_ROOT/lib/clean.awk" "$file" > "$tmp"; then
    rm -f "$tmp"
    log_error "cleaning failed: $file"
    return 1
  fi

  # awk always ends output with a newline; match the original's last byte so
  # a missing final newline is not reported as a change.
  if [[ -s "$file" && -s "$tmp" && "$(tail -c1 "$file" | od -An -c | tr -d ' ')" != '\n' ]]; then
    truncate -s -1 "$tmp"
  fi

  if ! cmp -s "$tmp" "$file"; then
    # Write through the existing inode so permissions and ownership survive.
    cat "$tmp" > "$file"
    log_debug "modified: $file"
  fi
  rm -f "$tmp"
}
