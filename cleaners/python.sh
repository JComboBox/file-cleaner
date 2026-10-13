#!/usr/bin/env bash
# Cleaner for type 'python': Python; preserves the shebang and coding line.
# Usage: cleaners/python.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" python \
  --line '^[[:space:]]*#' \
  --keep '^#!|^#.*coding[:=]'
