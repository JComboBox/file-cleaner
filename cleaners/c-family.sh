#!/usr/bin/env bash
# Cleaner for type 'c-family': C, C++, Java, C#, Kotlin, Swift, Rust, Scala.
# Usage: cleaners/c-family.sh FILE
set -euo pipefail
# shellcheck source=lib/clean.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/clean.sh"
load_config

fc_clean "$1" c-family \
  --line '^[[:space:]]*//' \
  --block-start '^[[:space:]]*/\*' \
  --block-end '\*/'
