#!/usr/bin/env bash
# Cleaner for type 'json': JSON has no comments, so only rules/json.patterns
# and snippet markers apply (both rarely useful). Kept for completeness.
# Usage: cleaners/json.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" json
