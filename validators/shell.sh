#!/usr/bin/env bash
# Validator for 'shell': parse without executing.
set -uo pipefail
case "$(head -n1 "$1")" in
  *zsh*) command -v zsh >/dev/null || exit 3; exec zsh -n "$1" ;;
  *)     exec bash -n "$1" ;;
esac
