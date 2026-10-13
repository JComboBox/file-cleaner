#!/usr/bin/env bash
# Validator for 'yaml': needs yamllint or PyYAML.
set -uo pipefail
if command -v yamllint >/dev/null; then
  yamllint -d relaxed --no-warnings "$1"
elif python3 -I -c 'import yaml' 2>/dev/null; then
  python3 -I -c 'import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1])))' "$1"
else
  exit 3
fi
