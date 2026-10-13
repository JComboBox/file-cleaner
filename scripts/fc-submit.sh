#!/usr/bin/env bash
# Commit changes, push the branch, and open a merge/pull request.
#
# Usage: scripts/fc-submit.sh [--dry-run] [--no-mr] REPO_DIR
#   --dry-run  commit locally and show the diff stat; do not push or open an MR
#   --no-mr    push the branch but do not open an MR
# Exit status: 0 on success (including "nothing to commit"), 1 on failure.
set -euo pipefail
# shellcheck source=lib/mr.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/mr.sh"
load_config

dry_run=0 open_mr=1
while (( $# )); do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --no-mr)   open_mr=0; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 64 ;;
    *) break ;;
  esac
done
(( $# == 1 )) || { echo "usage: $0 [--dry-run] [--no-mr] REPO_DIR" >&2; exit 64; }
repo="$1"

branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD)"
base="$(default_branch "$repo")"
[[ "$branch" != "$base" ]] || die "refusing to submit from the default branch ($base); run fc-branch.sh first"

if ! git_commit_all "$repo" "$FC_COMMIT_MESSAGE"; then
  log_info "nothing to commit in $repo"
  exit 0
fi
git -C "$repo" --no-pager diff --stat HEAD~1 >&2

if (( dry_run )); then
  log_info "dry run: committed locally on $branch; not pushing"
  exit 0
fi

git_login
git_push "$repo" "$branch"
if (( open_mr )); then
  url="$(git -C "$repo" remote get-url origin)"
  mr_url="$(open_merge_request "$url" "$branch" "$base")"
  [[ -n "$mr_url" ]] && log_info "merge request: $mr_url" && echo "$mr_url"
fi
exit 0
