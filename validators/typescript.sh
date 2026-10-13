#!/usr/bin/env bash
# Validator for 'typescript': uses tsc if installed. Only syntax errors
# (TS1xxx) count — type errors depend on the project's tsconfig and deps.
set -uo pipefail
command -v tsc >/dev/null || exit 3
out="$(tsc --noEmit --allowJs --jsx preserve --skipLibCheck --noResolve "$1" 2>&1)"
if grep -E 'error TS1[0-9]{3}:' <<<"$out" >&2; then
  exit 1
fi
exit 0
