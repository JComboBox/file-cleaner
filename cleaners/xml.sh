#!/usr/bin/env bash
# Cleaner for type 'xml': XML; <!-- --> headers, preserves the <?xml?> declaration.
# Usage: cleaners/xml.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" xml \
  --block-start '^[[:space:]]*<!--' \
  --block-end '-->' \
  --keep '^[[:space:]]*<\?xml'
