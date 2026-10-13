#!/usr/bin/env bash
# Validator for 'go': gofmt parses the file and reports syntax errors.
set -uo pipefail
command -v gofmt >/dev/null || exit 3
gofmt -e "$1" >/dev/null
