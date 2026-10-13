#!/usr/bin/env bash
# Cleaner for type 'javascript': JavaScript; // and /* */ headers, preserves the shebang.
# Usage: cleaners/javascript.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" javascript \
  --line '^[[:space:]]*//' \
  --block-start '^[[:space:]]*/\*' \
  --block-end '\*/' \
  --keep '^#!'
