#!/usr/bin/env bash
# Cleaner for type 'typescript': TypeScript/JSX; // and /* */ headers.
# Usage: cleaners/typescript.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" typescript \
  --line '^[[:space:]]*//' \
  --block-start '^[[:space:]]*/\*' \
  --block-end '\*/'
