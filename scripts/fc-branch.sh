#!/usr/bin/env bash
# Create (or reset) a work branch from the remote default branch.
#
# Usage: scripts/fc-branch.sh REPO_DIR [BRANCH] [BASE]
# BRANCH defaults to $FC_BRANCH; BASE defaults to the remote's default branch.
set -euo pipefail
# shellcheck source=lib/git.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git.sh"
load_config

(( $# >= 1 && $# <= 3 )) || { echo "usage: $0 REPO_DIR [BRANCH] [BASE]" >&2; exit 64; }
require_repo_dir "$1"
git_branch "$1" "${2:-$FC_BRANCH}" "${3:-}"
