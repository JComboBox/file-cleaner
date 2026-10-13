#!/usr/bin/env bash
# Validator for 'python': compile to an AST (no .pyc written).
set -uo pipefail
command -v python3 >/dev/null || exit 3
python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1], "rb").read(), sys.argv[1])' "$1"
