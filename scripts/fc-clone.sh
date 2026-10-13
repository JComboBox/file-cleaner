#!/usr/bin/env bash
# Authenticate and clone (or refresh) a repository.
#
# Usage: scripts/fc-clone.sh URL [DEST]
# DEST defaults to $FC_WORKDIR/<owner>/<repo>. Prints DEST on stdout.
set -euo pipefail
# shellcheck source=lib/git.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/git.sh"
load_config

(( $# >= 1 && $# <= 2 )) || { echo "usage: $0 URL [DEST]" >&2; exit 64; }
url="$1"
dest="${2:-$FC_WORKDIR/$(repo_slug "$url")}"

git_login
git_clone "$url" "$dest"
echo "$dest"
