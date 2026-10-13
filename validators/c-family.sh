#!/usr/bin/env bash
# Validator for 'c-family': compiling needs the project's build, so only a
# structural sanity check is done — balanced braces and block comments.
# Replace with a real compiler check if your repos have one.
set -uo pipefail
command -v python3 >/dev/null || exit 3
exec python3 -I "$(dirname "${BASH_SOURCE[0]}")/c_family_check.py" "$1"
