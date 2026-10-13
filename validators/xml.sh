#!/usr/bin/env bash
# Validator for 'xml': well-formedness check.
set -uo pipefail
if command -v xmllint >/dev/null; then
  xmllint --noout "$1"
elif command -v python3 >/dev/null; then
  python3 -I -c 'import sys, xml.dom.minidom as m; m.parse(sys.argv[1])' "$1"
else
  exit 3
fi
