#!/usr/bin/env bash
# Validator for 'json'.
set -uo pipefail
if command -v jq >/dev/null; then
  jq empty "$1"
elif command -v python3 >/dev/null; then
  python3 -I -m json.tool "$1" >/dev/null
else
  exit 3
fi
