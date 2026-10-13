#!/usr/bin/env bash
# Validator for 'javascript': node's syntax check.
set -uo pipefail
command -v node >/dev/null || exit 3
node --check "$1"
