#!/usr/bin/env bash
# Cleaner for type 'shell': shell scripts; preserves the shebang.
# Usage: cleaners/shell.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" shell \
  --line '^[[:space:]]*#' \
  --keep '^#!'
