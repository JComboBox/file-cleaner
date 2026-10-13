#!/usr/bin/env bash
# Shared helpers: logging, error handling, dependency checks, config loading.
# Source this file; do not execute it.

[[ -n "${_FC_COMMON_LOADED:-}" ]] && return 0
_FC_COMMON_LOADED=1

FC_ROOT="${FC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export FC_ROOT

# Log level: debug < info < warn < error. Logs go to stderr so stdout stays
# free for machine-readable output.
FC_LOG_LEVEL="${FC_LOG_LEVEL:-info}"

_fc_level_num() {
  case "$1" in
    debug) echo 0 ;; info) echo 1 ;; warn) echo 2 ;; error) echo 3 ;; *) echo 1 ;;
  esac
}

_fc_log() {
  local level="$1"; shift
  if (( $(_fc_level_num "$level") >= $(_fc_level_num "$FC_LOG_LEVEL") )); then
    printf '%s [%-5s] %s\n' "$(date -u +%H:%M:%S)" "$level" "$*" >&2
  fi
}

log_debug() { _fc_log debug "$@"; }
log_info()  { _fc_log info "$@"; }
log_warn()  { _fc_log warn "$@"; }
log_error() { _fc_log error "$@"; }

die() {
  log_error "$@"
  exit 1
}

# require_cmd CMD... — exit if any command is missing.
require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
  done
}

# is_true VALUE — true for 1/true/yes/on (case-insensitive).
is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

# load_config [FILE] — source a config file if present. Defaults to
# $FC_CONFIG, then config/file-cleaner.conf.
# Child scripts inherit the exported values and skip re-sourcing, so command
# line overrides made by the parent are not clobbered.
load_config() {
  local file="${1:-${FC_CONFIG:-$FC_ROOT/config/file-cleaner.conf}}"
  if [[ -z "${FC_CONFIG_LOADED:-}" && -f "$file" ]]; then
    log_debug "loading config: $file"
    # shellcheck source=/dev/null
    source "$file"
  fi
  : "${FC_BRANCH:=file-cleaner/$(date -u +%Y%m%d-%H%M%S)}"
  : "${FC_COMMIT_MESSAGE:=chore: remove obsolete headers and snippets}"
  : "${FC_MR_TITLE:=$FC_COMMIT_MESSAGE}"
  : "${FC_MR_DESCRIPTION:=Automated cleanup by file-cleaner. Every changed file passed its type validator.}"
  : "${FC_HEADER_PATTERN:=copyright|all rights reserved|licensed under|spdx-license-identifier}"
  : "${FC_SNIPPET_BEGIN:=FILE-CLEANER: BEGIN-REMOVE}"
  : "${FC_SNIPPET_END:=FILE-CLEANER: END-REMOVE}"
  : "${FC_REQUIRE_VALIDATOR:=0}"
  : "${FC_EXCLUDE_DIRS:=.git node_modules vendor dist build .venv}"
  : "${FC_TYPES:=}"
  : "${FC_PROVIDER:=auto}"
  : "${FC_WORKDIR:=${TMPDIR:-/tmp}/file-cleaner}"
  FC_CONFIG_LOADED=1
  export FC_CONFIG_LOADED FC_BRANCH FC_COMMIT_MESSAGE FC_MR_TITLE FC_MR_DESCRIPTION \
    FC_HEADER_PATTERN FC_SNIPPET_BEGIN FC_SNIPPET_END FC_REQUIRE_VALIDATOR \
    FC_EXCLUDE_DIRS FC_TYPES FC_PROVIDER FC_WORKDIR
}
