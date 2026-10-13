#!/usr/bin/env bash
# Cleaner for type 'html': HTML; <!-- --> headers, preserves the doctype.
# Usage: cleaners/html.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" html \
  --block-start '^[[:space:]]*<!--' \
  --block-end '-->' \
  --keep '^[[:space:]]*<!(DOCTYPE|doctype)'
