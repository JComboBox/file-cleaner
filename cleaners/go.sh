#!/usr/bin/env bash
# Cleaner for type 'go': Go; // and /* */ headers.
# Usage: cleaners/go.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" go \
  --line '^[[:space:]]*//' \
  --block-start '^[[:space:]]*/\*' \
  --block-end '\*/'
