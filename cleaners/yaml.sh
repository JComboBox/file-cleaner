#!/usr/bin/env bash
# Cleaner for type 'yaml': YAML; preserves a leading document marker.
# Usage: cleaners/yaml.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" yaml \
  --line '^[[:space:]]*#' \
  --keep '^(---|%YAML)'
